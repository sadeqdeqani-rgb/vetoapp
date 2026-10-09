<?php

namespace App\Services;

use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

class ProcessNotificationRecorder
{
    public function recordState(int $processId, int $processStateId, string $stateCode, Carbon $startedAt): void
    {
        $message = $this->message($processId, $stateCode, $startedAt);
        if ($message === null) return;

        $process = DB::table('processes')->where('process_id', $processId)->first([
            'process_id', 'process_type_code', 'target_geographic_level_code', 'target_geographic_id', 'title',
        ]);
        if ($process === null) throw new \UnexpectedValueException('Notification process was not found.');

        DB::table('notifications')->insertOrIgnore([
            'process_id' => $processId,
            'notification_type' => 'PROCESS_STATE_'.strtoupper($stateCode),
            'audience_scope' => 'GEOGRAPHIC_DOMAIN',
            'audience_geographic_level_code' => (int) $process->target_geographic_level_code,
            'audience_geographic_id' => (int) $process->target_geographic_id,
            'source_entity_type' => 'PROCESS_STATE',
            'source_entity_id' => $processStateId,
            'source_event_key' => hash('sha256', 'PROCESS_STATE|'.$processStateId, true),
            'title_template_key' => 'process.state.title',
            'body_template_key' => 'process.state.'.$stateCode,
            'payload_snapshot' => json_encode([
                'title' => (string) $process->title,
                'body' => $message,
                'process_id' => (string) $processId,
                'process_type' => (string) $process->process_type_code,
                'state_code' => $stateCode,
                'geographic_level_code' => (int) $process->target_geographic_level_code,
                'geographic_id' => (int) $process->target_geographic_id,
            ], JSON_THROW_ON_ERROR | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES),
            'priority' => 'NORMAL',
            'state' => 'READY',
            'created_at' => $startedAt,
        ]);
    }

    private function message(int $processId, string $stateCode, Carbon $startedAt): ?string
    {
        $process = DB::table('processes as p')
            ->join('process_lifecycle_policy_versions as policy', 'policy.process_lifecycle_policy_version_id', '=', 'p.process_lifecycle_policy_version_id')
            ->where('p.process_id', $processId)
            ->first(['p.title', 'p.process_type_code', 'p.voting_opens_at', 'p.voting_closes_at',
                'policy.waiting_period_seconds', 'policy.voting_period_seconds']);
        if ($process === null) return null;

        $name = match ($process->process_type_code) {
            'Referendum' => 'همه‌پرسی',
            'Election' => 'انتخابات',
            'Impeachment' => 'استیضاح',
            default => 'فرایند',
        };
        $title = '«'.$process->title.'»';

        return match ($stateCode) {
            'Supporting' => $name.' '.$title.' آغاز شد و در مرحلهٔ کسب حمایت قرار گرفت.',
            'Waiting' => $name.' با موضوع '.$title.' به مرحلهٔ انتظار رفت. شروع رأی‌گیری: '
                .$startedAt->copy()->addSeconds((int) $process->waiting_period_seconds)->toIso8601String()
                .'؛ پایان رأی‌گیری: '.$startedAt->copy()->addSeconds((int) ($process->waiting_period_seconds + $process->voting_period_seconds))->toIso8601String().'.',
            'VoteCasting' => $name.' '.$title.' آغاز شد و تا '.$this->date($process->voting_closes_at).' ادامه دارد.',
            'Publishing' => 'رأی‌گیری '.$name.' '.$title.' پایان یافت و صندوق در حال نهایی‌سازی است.',
            'Finalized' => 'نتایج نهایی '.$name.' '.$title.' منتشر شد.',
            'Failed' => 'فرایند '.$name.' '.$title.' ناموفق شد و ادامه پیدا نمی‌کند.',
            default => null,
        };
    }

    private function date(mixed $value): string
    {
        return $value === null ? '—' : Carbon::parse($value)->toIso8601String();
    }
}
