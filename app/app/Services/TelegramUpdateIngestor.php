<?php

namespace App\Services;

use App\Jobs\ProcessTelegramWebhookJob;
use App\Models\IntegrationInboxEntry;
use Illuminate\Support\Facades\DB;

class TelegramUpdateIngestor
{
    public function ingest(array $payload): bool
    {
        $externalId = isset($payload['update_id']) ? (string) $payload['update_id'] : null;
        $webhookSecret = (string) config('services.telegram.webhook_secret');
        $correlation = $externalId === null || $webhookSecret === ''
            ? null
            : hash_hmac('sha256', $externalId, $webhookSecret, true);

        [$inboxId, $isNew] = DB::transaction(function () use ($payload, $externalId, $correlation): array {
            if ($externalId !== null) {
                $existing = IntegrationInboxEntry::query()
                    ->where('channel', 'telegram')
                    ->where('external_message_id', $externalId)
                    ->value('inbox_entry_id');
                if ($existing !== null) {
                    return [(int) $existing, false];
                }
            }

            return [(int) IntegrationInboxEntry::query()->insertGetId([
                'channel' => 'telegram',
                'external_message_id' => $externalId,
                'correlation_hash' => $correlation,
                'payload' => json_encode($payload, JSON_UNESCAPED_UNICODE | JSON_THROW_ON_ERROR),
                'processed_status' => 'Pending',
                'received_at' => now(),
                'created_at' => now(),
                'updated_at' => now(),
            ]), true];
        });

        if ($isNew) {
            ProcessTelegramWebhookJob::dispatch($inboxId);
        }

        return $isNew;
    }
}
