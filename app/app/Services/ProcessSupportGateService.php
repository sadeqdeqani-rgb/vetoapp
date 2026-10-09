<?php

namespace App\Services;

use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Symfony\Component\HttpKernel\Exception\ConflictHttpException;

class ProcessSupportGateService
{
    private const WINDOWS = [30, 60, 90, 120, 180];
    private const SIMILARITY_THRESHOLD = 0.82;

    public function __construct(private readonly ReferendumSubjectNormalizer $normalizer) {}

    public function assertReferendumCanStart(int $level, int $geographicId, string $normalizedSubject): string
    {
        // A per-geography lock serializes first attempts even when their spelling differs.
        $this->lockOrCreateScope('REFERENDUM_SCOPE_LOCK', $level, $geographicId, null);
        $scope = DB::table('process_support_gate_scopes')
            ->where('gate_kind_code', 'REFERENDUM_SUBJECT')
            ->where('target_geographic_level_code', $level)
            ->where('target_geographic_id', $geographicId)
            ->whereNotNull('normalized_subject_snapshot')->get()
            ->map(function (object $candidate) use ($normalizedSubject): ?object {
                $candidate->similarity = $this->normalizer->similarity($normalizedSubject, (string) $candidate->normalized_subject_snapshot);

                return $candidate->similarity >= self::SIMILARITY_THRESHOLD ? $candidate : null;
            })->filter()->sort(function (object $a, object $b): int {
                return ($b->similarity <=> $a->similarity)
                    ?: ((int) $b->failed_support_streak <=> (int) $a->failed_support_streak)
                    ?: strcmp((string) $b->updated_at, (string) $a->updated_at);
            })->first();
        if ($scope === null) {
            $scope = $this->lockOrCreateScope('REFERENDUM_SUBJECT', $level, $geographicId, $normalizedSubject);
        } else {
            $scope = DB::table('process_support_gate_scopes')->where('gate_key', $scope->gate_key)->lockForUpdate()->firstOrFail();
        }
        $this->assertAvailable($scope, true);

        $hash = $this->normalizer->hash($normalizedSubject);
        $duplicate = DB::table('processes as p')
            ->join('process_states as ps', function ($join): void {
                $join->on('ps.process_id', '=', 'p.process_id')->whereNull('ps.current_state_completed_at');
            })
            ->where('p.process_type_code', 'Referendum')
            ->where('p.target_geographic_level_code', $level)
            ->where('p.target_geographic_id', $geographicId)
            ->where('p.normalized_title_hash', $hash)
            ->whereIn('ps.current_state_code', ['Supporting', 'Waiting', 'VoteCasting', 'Publishing', 'Finalized'])
            ->exists();
        if ($duplicate) {
            throw new ConflictHttpException('این موضوع برای همین حوزه قبلاً ثبت شده یا به حدنصاب رسیده است.');
        }

        $activeRows = DB::table('processes as p')
            ->join('process_states as ps', function ($join): void {
                $join->on('ps.process_id', '=', 'p.process_id')->whereNull('ps.current_state_completed_at');
            })
            ->where('p.process_type_code', 'Referendum')
            ->where('p.target_geographic_level_code', $level)->where('p.target_geographic_id', $geographicId)
            ->whereIn('ps.current_state_code', ['Supporting', 'Waiting', 'VoteCasting', 'Publishing'])
            ->get(['p.title', 'p.normalized_title']);
        foreach ($activeRows as $active) {
            if ($this->normalizer->similarity($normalizedSubject, (string) ($active->normalized_title ?: $active->title)) >= self::SIMILARITY_THRESHOLD) {
                throw new ConflictHttpException('موضوع مشابهی در همین حوزه در حال پیگیری است؛ آن را از فهرست موضوع‌های مشابه انتخاب کنید.');
            }
        }

        return (string) $scope->gate_key;
    }

    /** Check exact and close normalized matches before the user confirms a new proposal. */
    public function assertNoMatchingReferendumCooldown(int $level, int $geographicId, string $normalizedSubject): void
    {
        $hash = $this->normalizer->hash($normalizedSubject);
        $exactKey = $this->key('REFERENDUM_SUBJECT', $level, $geographicId, $hash);
        $exact = DB::table('process_support_gate_scopes')->where('gate_key', $exactKey)->first();
        if ($exact !== null) $this->assertAvailable($exact, true);

        $candidates = DB::table('process_support_gate_scopes')
            ->where('gate_kind_code', 'REFERENDUM_SUBJECT')
            ->where('target_geographic_level_code', $level)
            ->where('target_geographic_id', $geographicId)
            ->whereNotNull('normalized_subject_snapshot')
            ->get(['cooldown_until', 'successful_at', 'normalized_subject_snapshot']);

        foreach ($candidates as $candidate) {
            $similar = $this->normalizer->similarity($normalizedSubject, (string) $candidate->normalized_subject_snapshot) >= self::SIMILARITY_THRESHOLD;
            if ($similar && $candidate->successful_at !== null) {
                throw new ConflictHttpException('این موضوع قبلاً حدنصاب حمایت را کسب کرده و دوباره قابل پیشنهاد نیست.');
            }
            if ($similar && $candidate->cooldown_until !== null && Carbon::parse($candidate->cooldown_until)->isFuture()) {
                throw new ConflictHttpException($this->referendumMessage(Carbon::parse($candidate->cooldown_until)));
            }
        }
    }

    public function assertImpeachmentCanStart(int $level, int $geographicId): string
    {
        $scope = $this->lockOrCreateScope('IMPEACHMENT_SCOPE', $level, $geographicId, null);
        $this->assertAvailable($scope, false);

        return (string) $scope->gate_key;
    }

    public function bindProcess(int $processId, string $gateKey): void
    {
        DB::table('process_support_gate_assignments')->insertOrIgnore([
            'process_id' => $processId, 'gate_key' => $gateKey, 'created_at' => now(),
        ]);
    }

    /** Called only when a Supporting stage resolves to Waiting or support-expired Failed. */
    public function recordSupportResolution(object $process, bool $thresholdMet, Carbon $at): void
    {
        if (! in_array((string) $process->process_type_code, ['Referendum', 'Impeachment'], true)) return;
        $kind = $process->process_type_code === 'Referendum' ? 'REFERENDUM_SUBJECT' : 'IMPEACHMENT_SCOPE';
        $subject = $kind === 'REFERENDUM_SUBJECT' ? (string) ($process->normalized_title ?: $process->title) : null;
        $gateKey = DB::table('process_support_gate_assignments')->where('process_id', $process->process_id)->value('gate_key');
        $scope = $gateKey === null
            ? $this->lockOrCreateScope(
                $kind,
                (int) $process->target_geographic_level_code,
                (int) $process->target_geographic_id,
                $subject,
                is_string($process->normalized_title_hash ?? null) ? $process->normalized_title_hash : null,
            )
            : DB::table('process_support_gate_scopes')->where('gate_key', $gateKey)->lockForUpdate()->firstOrFail();

        if ($thresholdMet) {
            DB::table('process_support_gate_events')->insertOrIgnore([
                'process_id' => $process->process_id,
                'gate_key' => $scope->gate_key,
                'event_code' => 'SUPPORT_THRESHOLD_MET',
                'failed_support_streak' => 0,
                'cooldown_days' => 0,
                'event_at' => $at,
                'cooldown_until' => null,
                'created_at' => $at,
            ]);
            DB::table('process_support_gate_scopes')->where('gate_key', $scope->gate_key)->update([
                'failed_support_streak' => 0,
                'cooldown_until' => null,
                'successful_at' => $kind === 'REFERENDUM_SUBJECT' ? $at : null,
                'updated_at' => $at,
            ]);

            return;
        }

        $streak = min(count(self::WINDOWS), (int) $scope->failed_support_streak + 1);
        $days = self::WINDOWS[$streak - 1];
        $until = $at->copy()->addDays($days);
        DB::table('process_support_gate_events')->insertOrIgnore([
            'process_id' => $process->process_id,
            'gate_key' => $scope->gate_key,
            'event_code' => 'SUPPORT_THRESHOLD_NOT_MET',
            'failed_support_streak' => $streak,
            'cooldown_days' => $days,
            'event_at' => $at,
            'cooldown_until' => $until,
            'created_at' => $at,
        ]);
        DB::table('process_support_gate_scopes')->where('gate_key', $scope->gate_key)->update([
            'failed_support_streak' => $streak,
            'cooldown_until' => $until,
            'updated_at' => $at,
        ]);
    }

    private function lockOrCreateScope(string $kind, int $level, int $geographicId, ?string $subject, ?string $subjectHash = null): object
    {
        $subjectHash ??= $subject === null ? null : $this->normalizer->hash($subject);
        $key = $this->key($kind, $level, $geographicId, $subjectHash);
        DB::table('process_support_gate_scopes')->insertOrIgnore([
            'gate_key' => $key,
            'gate_kind_code' => $kind,
            'target_geographic_level_code' => $level,
            'target_geographic_id' => $geographicId,
            'normalized_subject_hash' => $subjectHash,
            'normalized_subject_snapshot' => $subject,
            'failed_support_streak' => 0,
            'cooldown_until' => null,
            'successful_at' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        return DB::table('process_support_gate_scopes')->where('gate_key', $key)->lockForUpdate()->firstOrFail();
    }

    private function key(string $kind, int $level, int $geographicId, ?string $subjectHash): string
    {
        $value = $kind.'|'.$level.'|'.$geographicId.($subjectHash === null ? '' : '|'.bin2hex($subjectHash));

        return hash('sha256', $value, true);
    }

    private function assertAvailable(object $scope, bool $referendum): void
    {
        if ($referendum && $scope->successful_at !== null) {
            throw new ConflictHttpException('این موضوع قبلاً حدنصاب حمایت را کسب کرده و دوباره قابل پیشنهاد نیست.');
        }
        if ($scope->cooldown_until !== null && Carbon::parse($scope->cooldown_until)->isFuture()) {
            $until = Carbon::parse($scope->cooldown_until);
            throw new ConflictHttpException($referendum ? $this->referendumMessage($until) : $this->impeachmentMessage($until));
        }
    }

    private function referendumMessage(Carbon $until): string
    {
        return 'این موضوع به‌تازگی حدنصاب حمایت را کسب نکرده است؛ ثبت دوبارهٔ موضوع مشابه تا '
            .$until->copy()->timezone(config('app.timezone'))->format('Y/m/d H:i').' ممکن نیست.';
    }

    private function impeachmentMessage(Carbon $until): string
    {
        return 'درخواست استیضاح برای این مسئول و حوزه به‌تازگی حدنصاب حمایت را کسب نکرده است؛ ثبت درخواست جدید تا '
            .$until->copy()->timezone(config('app.timezone'))->format('Y/m/d H:i').' ممکن نیست.';
    }
}
