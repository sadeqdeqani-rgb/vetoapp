<?php

namespace App\Http\Controllers;

use App\Jobs\ProcessTelegramWebhookJob;
use App\Models\IntegrationInboxEntry;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Bus;
use Illuminate\Support\Facades\DB;

class TelegramWebhookController extends Controller
{
    public function __invoke(Request $request, string $secret): JsonResponse
    {
        $configured = (string) config('services.telegram.webhook_secret');
        $headerSecret = (string) $request->header('X-Telegram-Bot-Api-Secret-Token');
        if (
            $configured === ''
            || (! hash_equals($configured, $secret)
                && ($headerSecret === '' || ! hash_equals($configured, $headerSecret)))
        ) {
            return response()->json(['ok' => true]);
        }

        $payload = $request->json()->all();
        $externalId = isset($payload['update_id']) ? (string) $payload['update_id'] : null;
        $correlation = $externalId === null
            ? null
            : hash_hmac('sha256', $externalId, (string) config('services.telegram.webhook_secret'), true);

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

        return response()->json(['ok' => true]);
    }
}
