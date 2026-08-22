<?php

namespace App\Jobs;

use App\Models\IntegrationInboxEntry;
use App\Models\UserTelegramIdentity;
use App\Services\RegistrationTransactionService;
use App\Services\TelegramBotClient;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Cache;
use RuntimeException;
use Throwable;

class ProcessTelegramWebhookJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public int $tries = 3;

    public function __construct(public int $inboxEntryId)
    {
    }

    public function handle(
        RegistrationTransactionService $registration,
        TelegramBotClient $telegram
    ): void {
        $entry = IntegrationInboxEntry::query()->findOrFail($this->inboxEntryId);
        $payload = $entry->payload;
        $message = $payload['message'] ?? null;

        if (! is_array($message)) {
            $entry->forceFill(['processed_status' => 'Ignored', 'processed_at' => now()])->save();
            return;
        }

        $from = $message['from'] ?? [];
        $chat = $message['chat'] ?? [];
        $telegramUserId = (int) ($from['id'] ?? 0);
        $chatId = (int) ($chat['id'] ?? 0);
        if ($telegramUserId <= 0 || $chatId === 0) {
            throw new RuntimeException('Telegram update has no valid sender.');
        }

        $identity = UserTelegramIdentity::query()
            ->where('telegram_user_id', $telegramUserId)
            ->first();

        if (isset($message['text']) && preg_match('/^\/start(?:\s+)([A-Za-z0-9_-]+)$/', trim($message['text']), $matches)) {
            $nonce = $matches[1];
            $draft = \App\Models\RegistrationDraft::query()
                ->where('telegram_link_nonce_hash', hash('sha256', $nonce, true))
                ->whereNull('telegram_link_nonce_used_at')
                ->where('telegram_link_nonce_expires_at', '>', now())
                ->firstOrFail();

            if ($identity !== null && $identity->registration_draft_id !== null
                && $identity->registration_draft_id !== $draft->registration_draft_id) {
                throw new RuntimeException('Telegram identity is linked to another draft.');
            }

            $identity ??= new UserTelegramIdentity();
            $identity->forceFill([
                'registration_draft_id' => $draft->registration_draft_id,
                'telegram_user_id' => $telegramUserId,
                'chat_id' => $chatId,
                'username' => $from['username'] ?? null,
                'link_status' => 'Pending',
                'phone_verification_status' => 'Pending',
                'last_seen_at' => now(),
            ])->save();

            Cache::put(
                "telegram:registration:nonce:{$telegramUserId}",
                ['draft_id' => $draft->registration_draft_id, 'nonce' => $nonce],
                $draft->telegram_link_nonce_expires_at
            );
            $telegram->requestContact($chatId);
        } elseif (isset($message['contact'])) {
            $stored = Cache::get("telegram:registration:nonce:{$telegramUserId}");
            if (! is_array($stored)) {
                throw new RuntimeException('Telegram registration state is missing or expired.');
            }

            $registrationIdentity = UserTelegramIdentity::query()
                ->where('telegram_user_id', $telegramUserId)
                ->where('registration_draft_id', $stored['draft_id'])
                ->firstOrFail();
            $registration->verifyTelegramContact(
                (int) $stored['draft_id'],
                (string) $stored['nonce'],
                [
                    'telegram_user_id' => $telegramUserId,
                    'chat_id' => $chatId,
                    'username' => $from['username'] ?? null,
                ],
                $message['contact']
            );
            Cache::forget("telegram:registration:nonce:{$telegramUserId}");
            $telegram->sendMessage($chatId, 'شماره شما با موفقیت تأیید شد.');
        } elseif ($identity !== null) {
            $identity->forceFill(['chat_id' => $chatId, 'last_seen_at' => now()])->save();
        }

        $entry->forceFill(['processed_status' => 'Processed', 'processed_at' => now()])->save();
    }

    public function failed(Throwable $exception): void
    {
        IntegrationInboxEntry::query()
            ->whereKey($this->inboxEntryId)
            ->update([
                'processed_status' => 'Failed',
                'processed_at' => now(),
            ]);
    }
}
