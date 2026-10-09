<?php

namespace App\Http\Controllers;

use App\Models\ProcessLifecyclePolicyVersion;
use App\Models\UserProfile;
use App\Services\ProcessReceiptSigner;
use App\Services\ProcessMerkleInclusionProof;
use App\Services\ProcessNotificationRecorder;
use App\Services\ProcessSupportGateService;
use App\Services\ReferendumSubjectNormalizer;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Database\QueryException;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpKernel\Exception\ConflictHttpException;
use Symfony\Component\HttpKernel\Exception\UnprocessableEntityHttpException;

class ReferendumProposalController extends Controller
{
    public function __construct(
        private readonly ReferendumSubjectNormalizer $normalizer,
        private readonly ProcessReceiptSigner $receipts,
        private readonly ProcessMerkleInclusionProof $merkleProofs,
        private readonly ProcessNotificationRecorder $notifications,
        private readonly ProcessSupportGateService $supportGate,
    ) {}

    public function index(Request $request): JsonResponse
    {
        $data = $request->validate([
            'geographic_level_code' => ['nullable', 'integer', 'between:1,4'],
            'geographic_id' => ['nullable', 'integer', 'min:1'],
            'page' => ['nullable', 'integer', 'min:1'],
            'per_page' => ['nullable', 'integer', 'between:1,50'],
        ]);
        if (array_key_exists('geographic_level_code', $data) !== array_key_exists('geographic_id', $data)) {
            throw ValidationException::withMessages(['geographic_id' => ['سطح و شناسهٔ حوزه باید با هم ارسال شوند.']]);
        }

        $query = $this->supportingProcessQuery();
        if (isset($data['geographic_level_code'])) {
            $this->filterProcessesWithinGeography(
                $query,
                (int) $data['geographic_level_code'],
                (int) $data['geographic_id'],
            );
        }
        $page = (int) ($data['page'] ?? 1);
        $perPage = (int) ($data['per_page'] ?? 20);
        $total = (clone $query)->count('p.process_id');
        $rows = $query->orderByDesc('ps.current_state_started_at')
            ->offset(($page - 1) * $perPage)->limit($perPage)->get();

        return response()->json(['data' => [
            'items' => $rows->map(fn ($row): array => $this->processSummary($row))->all(),
            'pagination' => ['page' => $page, 'per_page' => $perPage, 'total' => $total],
        ]]);
    }

    public function show(Request $request, int $processId): JsonResponse
    {
        $profile = $request->attributes->get('user_profile');
        $row = $this->supportingProcessQuery(false)->where('p.process_id', $processId)->first();
        abort_if($row === null || $row->process_type_code !== 'Referendum', 404);
        $summary = $this->processSummary($row);
        $identityKey = $this->supporterIdentityKey((string) $profile->national_id_hash);
        $hasSupported = DB::table('support_participations')
            ->where('process_id', $processId)
            ->where('supporter_identity_key', $identityKey)
            ->exists();
        $userScopeId = match ((int) $row->target_geographic_level_code) {
            1 => (int) $profile->country_id,
            2 => (int) $profile->province_id,
            3 => (int) $profile->county_id,
            4 => (int) $profile->settlement_id,
        };
        $matchesScope = $userScopeId === (int) $row->target_geographic_id;
        $summary['has_supported'] = $hasSupported;
        $summary['user_scope_matches'] = $matchesScope;
        $summary['can_support'] = $row->current_state_code === 'Supporting' && $matchesScope && ! $hasSupported;
        $summary['available_breakdown_levels'] = range((int) $row->target_geographic_level_code + 1, 4);
        if ((int) $row->target_geographic_level_code === 4) $summary['available_breakdown_levels'] = [];

        return response()->json(['data' => $summary]);
    }

    public function supportBreakdown(Request $request, int $processId): JsonResponse
    {
        $data = $request->validate([
            'geographic_level_code' => ['required', 'integer', 'between:2,4'],
            'search' => ['nullable', 'string', 'max:100'],
            'page' => ['nullable', 'integer', 'min:1'],
            'per_page' => ['nullable', 'integer', 'between:1,100'],
        ]);
        $process = DB::table('processes')->where('process_id', $processId)
            ->whereExists(fn ($placement) => $placement->selectRaw('1')
                ->from('process_shard_placements as placement')
                ->whereColumn('placement.process_id', 'processes.process_id')
                ->where('placement.placement_state_code', 'ACTIVE'))
            ->where('process_type_code', 'Referendum')->first();
        abort_if($process === null, 404);
        $level = (int) $data['geographic_level_code'];
        $targetLevel = (int) $process->target_geographic_level_code;
        if ($level <= $targetLevel) {
            throw ValidationException::withMessages(['geographic_level_code' => ['سطح گزارش باید پایین‌تر از دامنهٔ فرایند باشد.']]);
        }

        [$table, $idColumn, $supportColumn, $label] = match ($level) {
            2 => ['provinces', 'province_id', 'province_id', 'استان'],
            3 => ['counties', 'county_id', 'county_id', 'شهرستان'],
            4 => ['settlements', 'settlement_id', 'settlement_id', 'شهر یا روستا'],
        };
        $query = DB::table('support_participations as sp')
            ->join($table.' as geo', 'geo.'.$idColumn, '=', 'sp.'.$supportColumn)
            ->where('sp.process_id', $processId);
        $this->constrainSupportDomain($query, $process);
        if (($data['search'] ?? '') !== '') {
            $query->where('geo.name_fa', 'like', '%'.$data['search'].'%');
        }
        $grouped = (clone $query)->select('geo.'.$idColumn.' as geographic_id', 'geo.name_fa as name', DB::raw('COUNT(*) as support_count'))
            ->groupBy('geo.'.$idColumn, 'geo.name_fa');
        $page = (int) ($data['page'] ?? 1);
        $perPage = (int) ($data['per_page'] ?? 50);
        $total = DB::query()->fromSub(clone $grouped, 'support_groups')->count();
        $rows = $grouped->orderByDesc('support_count')->orderBy('name')
            ->offset(($page - 1) * $perPage)->limit($perPage)->get();

        return response()->json(['data' => [
            'geographic_level_code' => $level,
            'geographic_level_label' => $label,
            'items' => $rows->map(fn ($row): array => [
                'geographic_id' => (int) $row->geographic_id,
                'name' => $row->name,
                'support_count' => (int) $row->support_count,
            ])->all(),
            'pagination' => ['page' => $page, 'per_page' => $perPage, 'total' => $total],
        ]]);
    }

    private function supportingProcessQuery(bool $onlySupporting = true): \Illuminate\Database\Query\Builder
    {
        $supportCounts = DB::table('support_participations')
            ->select('process_id', DB::raw('COUNT(*) AS support_count'))
            ->groupBy('process_id');
        $query = DB::table('processes as p')
            ->join('process_shard_placements as placement', function ($join): void {
                $join->on('placement.process_id', '=', 'p.process_id')
                    ->where('placement.placement_state_code', '=', 'ACTIVE');
            })
            ->join('process_states as ps', function ($join): void {
                $join->on('ps.process_id', '=', 'p.process_id')->whereNull('ps.current_state_completed_at');
            })
            ->join('process_population_snapshots as pop', 'pop.process_id', '=', 'p.process_id')
            ->leftJoin('process_lifecycle_policy_versions as policy', 'policy.process_lifecycle_policy_version_id', '=', 'p.process_lifecycle_policy_version_id')
            ->leftJoinSub($supportCounts, 'sc', fn ($join) => $join->on('sc.process_id', '=', 'p.process_id'))
            ->leftJoin('countries as target_country', function ($join): void {
                $join->on('target_country.country_id', '=', 'p.target_geographic_id')
                    ->where('p.target_geographic_level_code', 1);
            })
            ->leftJoin('provinces as target_province', function ($join): void {
                $join->on('target_province.province_id', '=', 'p.target_geographic_id')
                    ->where('p.target_geographic_level_code', 2);
            })
            ->leftJoin('counties as target_county', function ($join): void {
                $join->on('target_county.county_id', '=', 'p.target_geographic_id')
                    ->where('p.target_geographic_level_code', 3);
            })
            ->leftJoin('settlements as target_settlement', function ($join): void {
                $join->on('target_settlement.settlement_id', '=', 'p.target_geographic_id')
                    ->where('p.target_geographic_level_code', 4);
            })
            ->where('p.process_type_code', 'Referendum');
        if ($onlySupporting) $query->where('ps.current_state_code', 'Supporting');

        return $query->select([
            'p.process_id', 'p.process_type_code', 'p.title', 'p.target_geographic_level_code',
            'p.target_geographic_id', 'p.created_at', 'p.voting_opens_at', 'p.voting_closes_at',
            'ps.current_state_code', 'ps.current_state_started_at', 'pop.frozen_population_total',
            'policy.threshold_rate_ppm', 'policy.min_support_count', DB::raw('COALESCE(sc.support_count, 0) as support_count'),
            DB::raw("CASE p.target_geographic_level_code WHEN 1 THEN 'کشور' WHEN 2 THEN 'استان' WHEN 3 THEN 'شهرستان' ELSE 'شهر یا روستا' END as geographic_label"),
            DB::raw('COALESCE(target_country.name_fa, target_province.name_fa, target_county.name_fa, target_settlement.name_fa) as geographic_name'),
        ]);
    }

    private function processSummary(object $row): array
    {
        $population = (int) $row->frozen_population_total;
        $threshold = (int) ceil($population * (int) $row->threshold_rate_ppm / 1_000_000);
        $threshold = max($threshold, (int) $row->min_support_count);

        return [
            'process_id' => (int) $row->process_id,
            'title' => $row->title,
            'process_type_code' => $row->process_type_code,
            'state_code' => $row->current_state_code,
            'geographic_level_code' => (int) $row->target_geographic_level_code,
            'geographic_id' => (int) $row->target_geographic_id,
            'geographic_label' => $row->geographic_label,
            'geographic_name' => $row->geographic_name,
            'support_count' => (int) $row->support_count,
            'required_support_count' => $threshold,
            'frozen_population_total' => $population,
            'support_started_at' => $row->current_state_started_at,
            'created_at' => $row->created_at,
        ];
    }

    private function constrainSupportDomain(\Illuminate\Database\Query\Builder $query, object $process): void
    {
        $column = match ((int) $process->target_geographic_level_code) {
            1 => 'sp.country_id',
            2 => 'sp.province_id',
            3 => 'sp.county_id',
            4 => 'sp.settlement_id',
        };
        $query->where($column, (int) $process->target_geographic_id);
    }

    private function filterProcessesWithinGeography(\Illuminate\Database\Query\Builder $query, int $level, int $id): void
    {
        $query->where(function ($scope) use ($level, $id): void {
            $scope->where(function ($exact) use ($level, $id): void {
                $exact->where('p.target_geographic_level_code', $level)
                    ->where('p.target_geographic_id', $id);
            });

            if ($level <= 1) {
                $scope->orWhereExists(fn ($sub) => $sub->selectRaw('1')->from('provinces as fp')
                    ->whereColumn('fp.province_id', 'p.target_geographic_id')
                    ->where('p.target_geographic_level_code', 2)->where('fp.country_id', $id));
                $scope->orWhereExists(fn ($sub) => $sub->selectRaw('1')->from('counties as fc')
                    ->join('provinces as fp', 'fp.province_id', '=', 'fc.province_id')
                    ->whereColumn('fc.county_id', 'p.target_geographic_id')
                    ->where('p.target_geographic_level_code', 3)->where('fp.country_id', $id));
                $scope->orWhereExists(fn ($sub) => $sub->selectRaw('1')->from('settlements as fs')
                    ->join('counties as fc', 'fc.county_id', '=', 'fs.county_id')
                    ->join('provinces as fp', 'fp.province_id', '=', 'fc.province_id')
                    ->whereColumn('fs.settlement_id', 'p.target_geographic_id')
                    ->where('p.target_geographic_level_code', 4)->where('fp.country_id', $id));
            } elseif ($level === 2) {
                $scope->orWhereExists(fn ($sub) => $sub->selectRaw('1')->from('counties as fc')
                    ->whereColumn('fc.county_id', 'p.target_geographic_id')
                    ->where('p.target_geographic_level_code', 3)->where('fc.province_id', $id));
                $scope->orWhereExists(fn ($sub) => $sub->selectRaw('1')->from('settlements as fs')
                    ->join('counties as fc', 'fc.county_id', '=', 'fs.county_id')
                    ->whereColumn('fs.settlement_id', 'p.target_geographic_id')
                    ->where('p.target_geographic_level_code', 4)->where('fc.province_id', $id));
            } elseif ($level === 3) {
                $scope->orWhereExists(fn ($sub) => $sub->selectRaw('1')->from('settlements as fs')
                    ->whereColumn('fs.settlement_id', 'p.target_geographic_id')
                    ->where('p.target_geographic_level_code', 4)->where('fs.county_id', $id));
            }
        });
    }

    public function preview(Request $request): JsonResponse
    {
        $data = $request->validate(['subject' => ['required', 'string', 'min:4', 'max:1000']]);
        $subject = $this->normalizer->normalize($data['subject']);
        $this->assertNormalizedLength($subject);
        $this->assertSubjectAllowed($subject);

        return response()->json(['data' => [
            'normalized_subject' => $subject,
            'normalization_version' => ReferendumSubjectNormalizer::VERSION,
            'geographic_scopes' => $this->geographicScopes($request->attributes->get('user_profile')),
        ]]);
    }

    public function similar(Request $request): JsonResponse
    {
        $data = $request->validate([
            'subject' => ['required', 'string', 'min:4', 'max:255'],
            'geographic_level_code' => ['required', 'integer', 'between:1,4'],
            'geographic_id' => ['required', 'integer', 'min:1'],
        ]);
        $profile = $request->attributes->get('user_profile');
        $this->assertScopeBelongsToUser($profile, (int) $data['geographic_level_code'], (int) $data['geographic_id']);
        $normalized = $this->normalizer->normalize($data['subject']);
        $this->assertNormalizedLength($normalized);
        $this->assertSubjectAllowed($normalized);
        $hash = $this->normalizer->hash($normalized);

        $supportCounts = DB::table('support_participations')
            ->select('process_id', DB::raw('COUNT(*) AS support_count'))
            ->groupBy('process_id');
        $candidates = DB::table('processes as p')
            ->join('process_shard_placements as placement', function ($join): void {
                $join->on('placement.process_id', '=', 'p.process_id')
                    ->where('placement.placement_state_code', '=', 'ACTIVE');
            })
            ->join('process_states as ps', function ($join): void {
                $join->on('ps.process_id', '=', 'p.process_id')
                    ->whereNull('ps.current_state_completed_at')
                    ->where('ps.current_state_code', '=', 'Supporting');
            })
            ->where('p.process_type_code', 'Referendum')
            ->where('p.target_geographic_level_code', (int) $data['geographic_level_code'])
            ->where('p.target_geographic_id', (int) $data['geographic_id'])
            ->leftJoinSub($supportCounts, 'sc', fn ($join) => $join->on('sc.process_id', '=', 'p.process_id'))
            ->orderByDesc('p.created_at')
            ->limit(1200)
            ->get(['p.process_id', 'p.title', 'p.normalized_title', 'p.normalized_title_hash', 'sc.support_count']);

        $matches = [];
        foreach ($candidates as $candidate) {
            $candidateNormalized = $candidate->normalized_title ?: $this->normalizer->normalize($candidate->title);
            $score = is_string($candidate->normalized_title_hash)
                && hash_equals($candidate->normalized_title_hash, $hash)
                ? 1.0
                : $this->normalizer->similarity($normalized, $candidateNormalized);
            if ($score < 0.34) continue;
            $matches[] = [
                'process_id' => (string) $candidate->process_id,
                'title' => $candidate->title,
                'normalized_subject' => $candidateNormalized,
                'similarity' => round($score, 4),
                'support_count' => (int) ($candidate->support_count ?? 0),
            ];
        }
        usort($matches, fn (array $a, array $b): int => $b['similarity'] <=> $a['similarity']);

        if ($matches === []) {
            $this->supportGate->assertNoMatchingReferendumCooldown(
                (int) $data['geographic_level_code'],
                (int) $data['geographic_id'],
                $normalized,
            );
        }

        return response()->json(['data' => [
            'normalized_subject' => $normalized,
            'matches' => array_slice($matches, 0, 10),
        ]]);
    }

    public function biometricChallenge(Request $request): JsonResponse
    {
        $data = $request->validate($this->selectionRules());
        $profile = $request->attributes->get('user_profile');
        $selection = $this->canonicalSelection($profile, $data);
        $userId = (int) $profile->user_id;
        $limiter = 'proposal-biometric-challenge:'.$userId;
        if ($this->rateLimited($limiter, 10)) {
            return response()->json(['message' => 'تعداد درخواست‌ها زیاد است؛ کمی بعد دوباره تلاش کنید.'], 429);
        }

        $credential = DB::table('user_biometric_credentials')
            ->where('user_id', $userId)->where('is_active', true)->first(['credential_id']);
        if ($credential === null) {
            throw new UnprocessableEntityHttpException('برای این حساب ورود بیومتریک فعال نیست.');
        }

        $challengeId = (string) Str::uuid();
        $challenge = random_bytes(32);
        $contextHash = hash('sha256', $this->canonicalJson($selection), true);
        DB::table('user_biometric_challenges')->insert([
            'challenge_id' => $challengeId,
            'user_id' => $userId,
            'credential_id' => $credential->credential_id,
            'purpose' => 'proposal',
            'challenge' => $challenge,
            'context_hash' => $contextHash,
            'expires_at' => now()->addMinutes(5),
            'created_at' => now(),
        ]);

        return response()->json(['data' => [
            'challenge_id' => $challengeId,
            'credential_id' => $this->uuidFromBinary((string) $credential->credential_id),
            'signed_payload' => $this->biometricPayload($challengeId, $challenge, $contextHash),
        ]]);
    }

    public function commit(Request $request): JsonResponse
    {
        $data = $request->validate($this->selectionRules() + [
            'idempotency_key' => ['required', 'uuid'],
            'confirmation_method' => ['required', 'in:password,biometric'],
            'password' => ['required_if:confirmation_method,password', 'nullable', 'string', 'max:255'],
            'challenge_id' => ['required_if:confirmation_method,biometric', 'nullable', 'uuid'],
            'credential_id' => ['required_if:confirmation_method,biometric', 'nullable', 'uuid'],
            'signature' => ['required_if:confirmation_method,biometric', 'nullable', 'string', 'max:2048'],
        ]);

        $profile = $request->attributes->get('user_profile');
        if ($this->rateLimited('referendum-proposal-commit:'.(int) $profile->user_id, 20)) {
            return response()->json(['message' => 'تعداد درخواست‌ها زیاد است؛ کمی بعد دوباره تلاش کنید.'], 429);
        }
        $account = $profile->account()->first();
        if ($account === null || $account->account_status !== 'Active'
            || ($account->locked_until !== null && $account->locked_until->isFuture())) {
            throw new UnprocessableEntityHttpException('حساب کاربری در وضعیت مجاز برای ثبت حمایت نیست.');
        }
        if ($data['confirmation_method'] === 'password') {
            if (! Hash::check($data['password'], (string) $account->password_hash)) {
                throw ValidationException::withMessages(['password' => ['رمز عبور صحیح نیست.']]);
            }
        }

        $selection = $this->canonicalSelection($profile, $data);
        if ($data['confirmation_method'] === 'biometric'
            && ! $this->consumeAndVerifyBiometricChallenge($data, (int) $profile->user_id, $selection)) {
            throw new UnprocessableEntityHttpException('تأیید بیومتریک نامعتبر یا منقضی است. دوباره تأیید کنید.');
        }
        $idempotencyKey = hash('sha256', str_replace('-', '', $data['idempotency_key']), true);
        $identityKey = $this->supporterIdentityKey((string) $profile->national_id_hash);

        try {
            $result = DB::transaction(function () use (
                $request, $data, $profile, $selection, $idempotencyKey, $identityKey
            ): array {
                $prior = DB::table('support_participations')->where('idempotency_key', $idempotencyKey)->first();
            if ($prior !== null) {
                if (! hash_equals((string) $prior->supporter_identity_key, $identityKey)) {
                    throw new ConflictHttpException('کلید تکرار درخواست متعلق به یک عملیات دیگر است.');
                }
                $priorProcess = DB::table('processes')->where('process_id', $prior->process_id)->first();
                if ($priorProcess === null
                    || (int) $priorProcess->target_geographic_level_code !== $selection['geographic_level_code']
                    || (int) $priorProcess->target_geographic_id !== $selection['geographic_id']
                    || $this->normalizer->normalize($priorProcess->title) !== $selection['title']) {
                    throw new ConflictHttpException('کلید تکرار درخواست قبلاً برای محتوای دیگری استفاده شده است.');
                }
                $receipt = DB::table('digital_receipts')->where('support_idempotency_key', $idempotencyKey)->first();
                if ($receipt !== null) return $this->receiptResponse($receipt);
            }

            $this->assertReferendumEnabled();

            $process = null;
            if ($selection['existing_process_id'] !== null) {
                $process = DB::table('processes as p')
                    ->join('process_shard_placements as placement', function ($join): void {
                        $join->on('placement.process_id', '=', 'p.process_id')
                            ->where('placement.placement_state_code', '=', 'ACTIVE');
                    })
                    ->join('process_states as ps', function ($join): void {
                        $join->on('ps.process_id', '=', 'p.process_id')->whereNull('ps.current_state_completed_at');
                    })
                    ->where('p.process_id', $selection['existing_process_id'])
                    ->where('p.process_type_code', 'Referendum')
                    ->where('ps.current_state_code', 'Supporting')
                    ->lockForUpdate()
                    ->first(['p.*']);
                if ($process === null
                    || (int) $process->target_geographic_level_code !== $selection['geographic_level_code']
                    || (int) $process->target_geographic_id !== $selection['geographic_id']
                    || $this->normalizer->normalize($process->title) !== $selection['title']) {
                    throw new ConflictHttpException('موضوع مشابه دیگر در مرحلهٔ دریافت حمایت نیست یا مشخصات آن تغییر کرده است.');
                }
            } else {
                $gateKey = $this->supportGate->assertReferendumCanStart(
                    (int) $selection['geographic_level_code'],
                    (int) $selection['geographic_id'],
                    (string) $selection['title'],
                );
                $process = $this->createProcess($profile, $selection);
                $this->supportGate->bindProcess((int) $process->process_id, $gateKey);
            }

            $duplicateSupport = DB::table('support_participations')
                ->where('process_id', $process->process_id)
                ->where('supporter_identity_key', $identityKey)
                ->exists();
            if ($duplicateSupport) {
                throw new ConflictHttpException('پیش‌تر از این موضوع حمایت کرده‌اید.');
            }

            $now = now();
            $supportId = DB::table('support_participations')->insertGetId([
                'process_id' => $process->process_id,
                'process_type_code' => 'Referendum',
                'supporter_identity_key' => $identityKey,
                'idempotency_key' => $idempotencyKey,
                'participated_at' => $now,
                'country_id' => $profile->country_id,
                'province_id' => $profile->province_id,
                'county_id' => $profile->county_id,
                'settlement_id' => $profile->settlement_id,
            ]);

            $receiptNumber = random_bytes(32);
            $issuedAt = $now->copy()->utc()->format('Y-m-d H:i:s.v');
            $keyId = (string) config('services.process_receipts.key_id');
            $payload = [
                'domain' => 'vetoapp-support-receipt-v1',
                'payload_version' => 1,
                'receipt_type_code' => 'SUPPORT',
                'receipt_number' => bin2hex($receiptNumber),
                'process_id' => (string) $process->process_id,
                'process_type_code' => 'Referendum',
                'event_title' => $process->title,
                'issued_at' => str_replace(' ', 'T', $issuedAt).'Z',
                'key_id' => $keyId,
            ];
            $receiptHash = hash('sha256', $this->canonicalJson($payload), true);
            $signed = $this->receipts->sign($receiptHash);
            $receiptId = DB::table('digital_receipts')->insertGetId([
                'process_id' => $process->process_id,
                'beneficiary_user_account_id' => $profile->user_id,
                'participant_identity_key' => $identityKey,
                'support_idempotency_key' => $idempotencyKey,
                'receipt_type_code' => 'SUPPORT',
                'process_type_code' => 'Referendum',
                'event_title_snapshot' => $process->title,
                'receipt_number' => $receiptNumber,
                'payload_version' => 1,
                'receipt_hash' => $receiptHash,
                'signature_value' => $signed['signature'],
                'key_id' => $signed['key_id'],
                'issued_at' => $issuedAt,
            ]);
            DB::table('digital_receipt_support_details')->insert([
                'digital_receipt_id' => $receiptId,
                'support_payload_version' => 1,
                'support_note_snapshot' => null,
                'created_at' => $now,
            ]);
            DB::table('process_projection_outbox_events')->insert([
                'process_id' => $process->process_id,
                'event_type_code' => 'SUPPORT_COMMITTED',
                'source_record_id' => $supportId,
                'event_key' => hash('sha256', 'SUPPORT_COMMITTED|'.bin2hex($idempotencyKey), true),
                'payload' => json_encode([
                    'process_id' => (string) $process->process_id,
                    'support_participation_id' => (string) $supportId,
                    'geographic_level_code' => $selection['geographic_level_code'],
                    'geographic_id' => $selection['geographic_id'],
                ], JSON_THROW_ON_ERROR | JSON_UNESCAPED_UNICODE),
                'created_at' => $now,
                'processed_at' => null,
                'attempts' => 0,
            ]);

            return $this->receiptResponse(DB::table('digital_receipts')->where('digital_receipt_id', $receiptId)->first());
            }, 3);
        } catch (QueryException $exception) {
            // A concurrent retry may race at the unique idempotency/process
            // constraint. The losing request returns the winner's receipt once
            // the winning transaction has committed instead of creating a second
            // process or surfacing a database error.
            $driverCode = (int) ($exception->errorInfo[1] ?? 0);
            if (! in_array($driverCode, [1062, 23000], true)) throw $exception;
            $prior = DB::table('support_participations')->where('idempotency_key', $idempotencyKey)->first();
            if ($prior === null) throw $exception;
            if (! hash_equals((string) $prior->supporter_identity_key, $identityKey)) {
                throw new ConflictHttpException('کلید تکرار درخواست متعلق به یک عملیات دیگر است.');
            }
            $priorProcess = DB::table('processes')->where('process_id', $prior->process_id)->first();
            if ($priorProcess === null
                || (int) $priorProcess->target_geographic_level_code !== $selection['geographic_level_code']
                || (int) $priorProcess->target_geographic_id !== $selection['geographic_id']
                || $this->normalizer->normalize($priorProcess->title) !== $selection['title']) {
                throw new ConflictHttpException('کلید تکرار درخواست قبلاً برای محتوای دیگری استفاده شده است.');
            }
            $receipt = DB::table('digital_receipts')->where('support_idempotency_key', $idempotencyKey)->first();
            if ($receipt === null) throw $exception;
            return response()->json(['data' => $this->receiptResponse($receipt)]);
        }

        return response()->json(['data' => $result], 201);
    }

    public function receiptKeys(): JsonResponse
    {
        return response()->json(['data' => $this->receipts->publicKeys()]);
    }

    public function verifyReceipt(Request $request): JsonResponse
    {
        $rateKey = 'public-process-receipt-verify:'.hash('sha256', (string) $request->ip());
        if (RateLimiter::tooManyAttempts($rateKey, 30)) {
            return response()->json(['message' => 'تعداد درخواست‌های بررسی رسید زیاد است؛ کمی بعد دوباره تلاش کنید.'], 429);
        }
        RateLimiter::hit($rateKey, 60);

        $data = $request->validate(['receipt_number' => ['required', 'string', 'size:43', 'regex:/^[A-Za-z0-9_-]+$/']]);
        $number = $this->base64UrlDecode($data['receipt_number']);
        if ($number === null || strlen($number) !== 32) {
            throw ValidationException::withMessages(['receipt_number' => ['شماره رسید معتبر نیست.']]);
        }
        $receipt = DB::table('digital_receipts')->where('receipt_number', $number)->first();
        if ($receipt === null) return response()->json(['message' => 'رسیدی با این شناسه پیدا نشد.'], 404);
        $payload = $this->receiptPayload($receipt);
        $canonical = $this->canonicalJson($payload);
        $publicKey = DB::table('process_receipt_signing_public_keys')->where('key_id', $receipt->key_id)->value('public_key');
        $valid = false;
        if (extension_loaded('sodium') && is_string($publicKey)
            && hash_equals((string) $receipt->receipt_hash, hash('sha256', $canonical, true))) {
            try {
                $valid = sodium_crypto_sign_verify_detached(
                    (string) $receipt->signature_value,
                    (string) $receipt->receipt_hash,
                    $publicKey,
                );
            } catch (\SodiumException | \TypeError) {
                $valid = false;
            }
        }

        return response()->json(['data' => [
            'valid' => $valid,
            'payload' => $payload,
            'receipt_hash' => $this->base64UrlEncode((string) $receipt->receipt_hash),
            'signature' => $this->base64UrlEncode((string) $receipt->signature_value),
            'algorithm' => 'Ed25519',
            'inclusion_proof' => $this->merkleProofs->forReceipt($receipt),
        ]]);
    }

    private function createProcess(UserProfile $profile, array $selection): object
    {
        $policy = ProcessLifecyclePolicyVersion::query()->where('is_active', true)
            ->where('effective_from', '<=', now())
            ->where(fn ($query) => $query->whereNull('effective_to')->orWhere('effective_to', '>', now()))
            ->lockForUpdate()->first();
        if ($policy === null) throw new UnprocessableEntityHttpException('سیاست چرخهٔ همه‌پرسی تنظیم نشده است.');

        $populationQuery = DB::table('user_profiles as up')
            ->join('user_accounts as ua', 'ua.user_id', '=', 'up.user_id')
            ->where('up.is_active', true)->where('ua.account_status', 'Active');
        $geoColumn = match ($selection['geographic_level_code']) {
            1 => 'country_id', 2 => 'province_id', 3 => 'county_id', 4 => 'settlement_id',
        };
        $population = (int) $populationQuery->where('up.'.$geoColumn, $selection['geographic_id'])->count();
        if ($population < 1) throw new UnprocessableEntityHttpException('برای این دامنهٔ جغرافیایی کاربر فعالی ثبت نشده است.');

        $now = now();
        $opensAt = $now->copy()->addSeconds($policy->support_period_seconds + $policy->waiting_period_seconds);
        $closesAt = $opensAt->copy()->addSeconds($policy->voting_period_seconds);
        $hash = $this->normalizer->hash($selection['title']);
        $now = now();
        // Until process-owned reads/writes are routed through a physical shard,
        // only place new processes on the connection currently executing this
        // transaction. Additional connection aliases must not be selected early.
        $shard = DB::table('shard_catalog')
            ->where('shard_state_code', 'ONLINE')
            ->where('connection_name', DB::getDefaultConnection())
            ->orderByRaw("CASE WHEN shard_id = 'primary' THEN 0 ELSE 1 END")
            ->first(['shard_id', 'connection_name']);
        if ($shard === null) {
            throw new UnprocessableEntityHttpException('هیچ شارد فعالی برای ایجاد فرایند در دسترس نیست.');
        }
        $shardId = (string) $shard->shard_id;

        // The unsharded placement registry allocates the globally unique process_id.
        // In this deployment, the single physical MySQL database is the `primary` shard.
        $processId = DB::table('process_shard_placements')->insertGetId([
            'shard_id' => $shardId,
            'placement_state_code' => 'CREATING',
            'placement_version' => 1,
            'assigned_at' => $now,
            'activated_at' => null,
            'updated_at' => $now,
        ], 'process_id');

        DB::table('processes')->insert([
            'process_id' => $processId,
            'process_type_code' => 'Referendum',
            'process_lifecycle_policy_version_id' => $policy->process_lifecycle_policy_version_id,
            'target_geographic_level_code' => $selection['geographic_level_code'],
            'target_geographic_id' => $selection['geographic_id'],
            'title' => $selection['title'],
            'normalized_title' => $selection['title'],
            'normalized_title_hash' => $hash,
            'normalization_version' => ReferendumSubjectNormalizer::VERSION,
            'created_by_user_id' => $profile->user_id,
            'voting_opens_at' => $opensAt,
            'voting_closes_at' => $closesAt,
            'ballot_schema_id' => 'REFERENDUM_YES_NO',
            'ballot_schema_version' => 1,
            'canonical_encoding_version' => 1,
            'vote_token_ttl_seconds' => 300,
            'result_publication_interval_seconds' => 600,
            'created_at' => $now,
            'updated_at' => $now,
        ]);
        $stateId = DB::table('process_states')->insertGetId([
            'process_id' => $processId,
            'current_state_code' => 'Supporting',
            'current_state_started_at' => $now,
            'current_state_completed_at' => null,
            'created_at' => $now,
            'updated_at' => $now,
        ]);
        $this->notifications->recordState($processId, (int) $stateId, 'Supporting', $now);
        DB::table('process_population_snapshots')->insert([
            'process_id' => $processId,
            'frozen_population_total' => $population,
            'captured_at' => $now,
        ]);
        DB::table('process_ballot_options')->insert([
            ['process_id' => $processId, 'option_key' => 'YES', 'option_type_code' => 'YES', 'display_label' => 'موافق', 'is_active' => true, 'created_at' => $now],
            ['process_id' => $processId, 'option_key' => 'NO', 'option_type_code' => 'NO', 'display_label' => 'مخالف', 'is_active' => true, 'created_at' => $now],
        ]);

        DB::table('process_shard_placements')->where('process_id', $processId)->update([
            'placement_state_code' => 'ACTIVE',
            'activated_at' => $now,
            'updated_at' => $now,
        ]);
        DB::table('process_shard_placement_history')->insert([
            [
                'process_id' => $processId,
                'placement_version' => 1,
                'placement_event_no' => 1,
                'source_shard_id' => null,
                'destination_shard_id' => $shardId,
                'operation_event_code' => 'PLACEMENT_PREPARED',
                'created_at' => $now,
                'completed_at' => $now,
            ],
            [
                'process_id' => $processId,
                'placement_version' => 1,
                'placement_event_no' => 2,
                'source_shard_id' => null,
                'destination_shard_id' => $shardId,
                'operation_event_code' => 'CUTOVER',
                'created_at' => $now,
                'completed_at' => $now,
            ],
        ]);

        return DB::table('processes')->where('process_id', $processId)->first();
    }

    private function selectionRules(): array
    {
        return [
            'subject' => ['required', 'string', 'min:4', 'max:255'],
            'geographic_level_code' => ['required', 'integer', 'between:1,4'],
            'geographic_id' => ['required', 'integer', 'min:1'],
            'existing_process_id' => ['nullable', 'integer', 'min:1'],
        ];
    }

    private function canonicalSelection(UserProfile $profile, array $data): array
    {
        $title = $this->normalizer->normalize($data['subject']);
        $this->assertNormalizedLength($title);
        $this->assertSubjectAllowed($title);
        $level = (int) $data['geographic_level_code'];
        $geoId = (int) $data['geographic_id'];
        $this->assertScopeBelongsToUser($profile, $level, $geoId);
        $existingProcessId = isset($data['existing_process_id']) ? (int) $data['existing_process_id'] : null;
        return [
            'title' => $title,
            'geographic_level_code' => $level,
            'geographic_id' => $geoId,
            'existing_process_id' => $existingProcessId,
        ];
    }

    private function assertSubjectAllowed(string $normalized): void
    {
        $terms = DB::table('referendum_directional_terms')->where('is_active', true)->pluck('normalized_term');
        if ($this->normalizer->containsDirectionalTerm($normalized, $terms)) {
            throw ValidationException::withMessages(['subject' => ['موضوع شامل عبارت جهت‌دار یا سوگیرانه است و قابل ثبت نیست.']]);
        }
    }

    private function assertNormalizedLength(string $normalized): void
    {
        $length = function_exists('mb_strlen') ? mb_strlen($normalized, 'UTF-8') : strlen($normalized);
        if ($length < 4 || $length > 255) {
            throw ValidationException::withMessages(['subject' => ['موضوع نرمال‌شده باید بین ۴ تا ۲۵۵ نویسه باشد.']]);
        }
    }

    private function assertScopeBelongsToUser(UserProfile $profile, int $level, int $id): void
    {
        $expected = match ($level) {
            1 => (int) $profile->country_id,
            2 => (int) $profile->province_id,
            3 => (int) $profile->county_id,
            4 => (int) $profile->settlement_id,
        };
        if ($id !== $expected) throw ValidationException::withMessages(['geographic_id' => ['دامنهٔ انتخاب‌شده با اطلاعات جغرافیایی حساب شما مطابقت ندارد.']]);
    }

    private function geographicScopes(UserProfile $profile): array
    {
        $country = DB::table('countries')->where('country_id', $profile->country_id)->first(['country_id', 'name_fa']);
        $province = DB::table('provinces')->where('province_id', $profile->province_id)->first(['province_id', 'name_fa']);
        $county = DB::table('counties')->where('county_id', $profile->county_id)->first(['county_id', 'name_fa']);
        $settlement = DB::table('settlements')->where('settlement_id', $profile->settlement_id)->first(['settlement_id', 'name_fa']);

        return array_values(array_filter([
            $country ? ['geographic_level_code' => 1, 'geographic_id' => (int) $country->country_id, 'label' => 'کشور', 'name' => $country->name_fa] : null,
            $province ? ['geographic_level_code' => 2, 'geographic_id' => (int) $province->province_id, 'label' => 'استان کاربر', 'name' => $province->name_fa] : null,
            $county ? ['geographic_level_code' => 3, 'geographic_id' => (int) $county->county_id, 'label' => 'شهرستان کاربر', 'name' => $county->name_fa] : null,
            $settlement ? ['geographic_level_code' => 4, 'geographic_id' => (int) $settlement->settlement_id, 'label' => 'شهر یا روستای کاربر', 'name' => $settlement->name_fa] : null,
        ]));
    }

    private function assertReferendumEnabled(): void
    {
        $state = (int) DB::table('system_states')->value('state_value');
        if ($state < 2) throw new UnprocessableEntityHttpException('بخش همه‌پرسی هنوز فعال نشده است.');
    }

    private function consumeAndVerifyBiometricChallenge(array $data, int $userId, array $selection): bool
    {
        $limiter = 'proposal-biometric-verify:'.$userId;
        if ($this->rateLimited($limiter, 10)) return false;
        return DB::transaction(function () use ($data, $userId, $selection): bool {
            $challenge = DB::table('user_biometric_challenges')->where('challenge_id', $data['challenge_id'])->lockForUpdate()->first();
            $credentialBinary = hex2bin(str_replace('-', '', $data['credential_id'])) ?: '';
            $contextHash = hash('sha256', $this->canonicalJson($selection), true);
            if ($challenge === null || $challenge->purpose !== 'proposal' || (int) $challenge->user_id !== $userId
                || $challenge->credential_id === null || ! hash_equals((string) $challenge->credential_id, $credentialBinary)
                || $challenge->context_hash === null || ! hash_equals((string) $challenge->context_hash, $contextHash)
                || $challenge->consumed_at !== null || now()->greaterThanOrEqualTo($challenge->expires_at)) {
                return false;
            }
            DB::table('user_biometric_challenges')->where('challenge_id', $data['challenge_id'])->update(['consumed_at' => now()]);
            $credential = DB::table('user_biometric_credentials')->where('user_id', $userId)
                ->where('credential_id', $credentialBinary)->where('is_active', true)->first();
            $signature = $this->base64UrlDecode($data['signature']);
            $valid = $credential !== null && $signature !== null && $this->verifyP256(
                (string) $credential->public_key,
                $signature,
                $this->biometricPayload($data['challenge_id'], (string) $challenge->challenge, (string) $challenge->context_hash),
            );
            if ($valid) {
                DB::table('user_biometric_credentials')->where('biometric_credential_id', $credential->biometric_credential_id)
                    ->increment('sign_count', 1, ['last_used_at' => now(), 'updated_at' => now()]);
            }
            return $valid;
        });
    }

    private function verifyP256(string $der, string $signature, string $payload): bool
    {
        $pem = "-----BEGIN PUBLIC KEY-----\n".chunk_split(base64_encode($der), 64, "\n")."-----END PUBLIC KEY-----\n";
        $key = openssl_pkey_get_public($pem);
        if ($key === false) return false;
        $details = openssl_pkey_get_details($key);
        return ($details['type'] ?? null) === OPENSSL_KEYTYPE_EC
            && in_array($details['ec']['curve_name'] ?? '', ['prime256v1', 'P-256'], true)
            && openssl_verify($payload, $signature, $key, OPENSSL_ALGO_SHA256) === 1;
    }

    private function biometricPayload(string $id, string $challenge, string $contextHash): string
    {
        return 'vetoapp-biometric-v1|proposal|'.$id.'|'.$this->base64UrlEncode($challenge).'|'.$this->base64UrlEncode($contextHash);
    }

    private function receiptPayload(object $receipt): array
    {
        $payload = [
            'domain' => $receipt->receipt_type_code === 'VOTE' ? 'vetoapp-vote-receipt-v1' : 'vetoapp-support-receipt-v1',
            'payload_version' => (int) $receipt->payload_version,
            'receipt_type_code' => $receipt->receipt_type_code,
            'receipt_number' => bin2hex((string) $receipt->receipt_number),
            'process_id' => (string) $receipt->process_id,
            'process_type_code' => $receipt->process_type_code,
            'event_title' => $receipt->event_title_snapshot,
            'issued_at' => \Illuminate\Support\Carbon::parse($receipt->issued_at, 'UTC')->format('Y-m-d\TH:i:s.v\Z'),
            'key_id' => $receipt->key_id,
        ];
        if ($receipt->receipt_type_code === 'VOTE') {
            $vote = DB::table('digital_receipt_vote_details as d')
                ->join('ballot_box_entries as b', 'b.ballot_box_entry_id', '=', 'd.ballot_box_entry_id')
                ->where('d.digital_receipt_id', $receipt->digital_receipt_id)
                ->first(['b.sequence_no', 'd.ballot_commitment', 'd.ballot_choice_key_snapshot', 'd.ballot_choice_label_snapshot']);
            if ($vote === null) return $payload + ['sequence_no' => null, 'ballot_commitment' => null];
            $payload['sequence_no'] = (int) $vote->sequence_no;
            $payload['ballot_commitment'] = $this->base64UrlEncode((string) $vote->ballot_commitment);
            if ((int) $receipt->payload_version >= 2) {
                $payload['ballot_choice_key'] = $vote->ballot_choice_key_snapshot;
                $payload['ballot_choice_label'] = $vote->ballot_choice_label_snapshot;
            }
        }
        return $payload;
    }

    private function receiptResponse(object $receipt): array
    {
        return [
            'receipt_number' => $this->base64UrlEncode((string) $receipt->receipt_number),
            'receipt_hash' => $this->base64UrlEncode((string) $receipt->receipt_hash),
            'signature' => $this->base64UrlEncode((string) $receipt->signature_value),
            'key_id' => $receipt->key_id,
            'algorithm' => 'Ed25519',
            'issued_at' => $receipt->issued_at,
            'process_id' => (string) $receipt->process_id,
            'title' => $receipt->event_title_snapshot,
        ];
    }

    private function supporterIdentityKey(string $nationalIdHash): string
    {
        $key = (string) config('services.process_receipts.identity_hmac_key');
        if (strlen($key) < 32) throw new \RuntimeException('PROCESS_IDENTITY_HMAC_KEY must be configured with at least 32 characters.');
        return hash_hmac('sha256', 'support-v1|'.bin2hex($nationalIdHash), $key, true);
    }

    private function canonicalJson(array $payload): string
    {
        ksort($payload);
        return json_encode($payload, JSON_THROW_ON_ERROR | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    }

    private function rateLimited(string $key, int $max): bool
    {
        if (RateLimiter::tooManyAttempts($key, $max)) return true;
        RateLimiter::hit($key, 60);
        return false;
    }

    private function base64UrlEncode(string $value): string
    {
        return rtrim(strtr(base64_encode($value), '+/', '-_'), '=');
    }

    private function base64UrlDecode(string $value): ?string
    {
        $decoded = base64_decode(strtr($value, '-_', '+/').str_repeat('=', (4 - strlen($value) % 4) % 4), true);
        return $decoded === false ? null : $decoded;
    }

    private function uuidFromBinary(string $binary): string
    {
        $hex = bin2hex($binary);
        return substr($hex, 0, 8).'-'.substr($hex, 8, 4).'-'.substr($hex, 12, 4).'-'.substr($hex, 16, 4).'-'.substr($hex, 20);
    }
}
