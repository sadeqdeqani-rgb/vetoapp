<?php

namespace App\Jobs;

use App\Http\Controllers\TelegramPasswordRecoveryController;
use App\Models\IntegrationInboxEntry;
use App\Models\RegistrationDraft;
use App\Models\UserProfile;
use App\Models\UserTelegramIdentity;
use App\Services\OtpService;
use App\Services\RegistrationTransactionService;
use App\Services\TelegramBotClient;
use App\Support\TelegramContactMismatchException;
use App\Support\MobileIdentity;
use App\Support\MobileNumber;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use RuntimeException;
use Throwable;

class ProcessTelegramWebhookJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public int $tries = 3;

    public function __construct(public int $inboxEntryId) {}

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
            $startPayload = $matches[1];
            if (str_starts_with($startPayload, 'reset-')) {
                $this->issuePasswordRecoveryOtp(
                    substr($startPayload, strlen('reset-')),
                    $telegramUserId,
                    $chatId,
                    $telegram,
                );
                $entry->forceFill(['processed_status' => 'Processed', 'processed_at' => now()])->save();

                return;
            }
            $nonce = $startPayload;
            $draft = RegistrationDraft::query()
                ->where('telegram_link_nonce_hash', hash('sha256', $nonce, true))
                ->whereNull('telegram_link_nonce_used_at')
                ->where('telegram_link_nonce_expires_at', '>', now())
                ->firstOrFail();

            $identity = DB::transaction(function () use ($telegramUserId, $chatId, $from, $draft): ?UserTelegramIdentity {
                $identity = UserTelegramIdentity::query()
                    ->where('telegram_user_id', $telegramUserId)
                    ->lockForUpdate()
                    ->first();

                if ($identity !== null && $identity->registration_draft_id !== null
                    && $identity->registration_draft_id !== $draft->registration_draft_id) {
                    $previousDraft = RegistrationDraft::query()
                        ->whereKey($identity->registration_draft_id)
                        ->lockForUpdate()
                        ->first();
                    $previousDraftExpired = $previousDraft !== null && (
                        $previousDraft->state_code === 'Expired'
                        || ($previousDraft->state_code === 'Initiated' && $previousDraft->expires_at->isPast())
                    );

                    if ($identity->user_id !== null || ! $previousDraftExpired) {
                        throw new RuntimeException('Telegram identity is linked to another draft.');
                    }

                    // Reuse an unregistered Telegram identity only after its old draft expired.
                    // Ask for Contact again so verification is bound to the new draft's phone.
                    $identity->forceFill([
                        'registration_draft_id' => $draft->registration_draft_id,
                        'link_status' => 'Pending',
                        'verified_mobile_hash' => null,
                        'phone_verified_at' => null,
                        'phone_verification_status' => 'Pending',
                        'linked_at' => null,
                        'chat_id' => $chatId,
                        'username' => $from['username'] ?? null,
                        'last_seen_at' => now(),
                    ])->save();
                }

                return $identity;
            });

            $identity ??= new UserTelegramIdentity;
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
        } elseif (isset($message['text']) && preg_match('/^\/start(?:@\w+)?$/', trim($message['text']))) {
            $telegram->sendMessage(
                $chatId,
                'برای ثبت‌نام، ثبت‌نام را از داخل اپ آغاز کنید و لینک اختصاصی بات را باز کنید.',
            );
        } elseif (isset($message['contact'])) {
            $recoveryNonce = Cache::get("telegram:password-recovery:contact:{$telegramUserId}");
            if (is_string($recoveryNonce) && $recoveryNonce !== '') {
                $this->verifyPasswordRecoveryContact(
                    $recoveryNonce,
                    $telegramUserId,
                    $chatId,
                    $message['contact'],
                    $telegram,
                );
                $entry->forceFill(['processed_status' => 'Processed', 'processed_at' => now()])->save();

                return;
            }

            $stored = Cache::get("telegram:registration:nonce:{$telegramUserId}");
            if (! is_array($stored)) {
                throw new RuntimeException('Telegram registration state is missing or expired.');
            }

            $registrationIdentity = UserTelegramIdentity::query()
                ->where('telegram_user_id', $telegramUserId)
                ->where('registration_draft_id', $stored['draft_id'])
                ->firstOrFail();
            $contactVerified = false;
            try {
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
                $contactVerified = true;
            } catch (TelegramContactMismatchException) {
                DB::transaction(function () use ($telegramUserId, $stored): void {
                    UserTelegramIdentity::query()
                        ->where('telegram_user_id', $telegramUserId)
                        ->where('registration_draft_id', (int) $stored['draft_id'])
                        ->whereNull('user_id')
                        ->update([
                            'registration_draft_id' => null,
                            'link_status' => 'Pending',
                            'verified_mobile_hash' => null,
                            'phone_verified_at' => null,
                            'phone_verification_status' => 'Pending',
                            'linked_at' => null,
                            'updated_at' => now(),
                        ]);
                });
                Cache::forget("telegram:registration:nonce:{$telegramUserId}");
                $telegram->sendMessage(
                    $chatId,
                    'شماره‌ای که در اپ وارد کرده‌اید با شمارهٔ حساب تلگرام شما مطابقت ندارد؛ شماره تأیید نشد و ثبت‌نام ادامه پیدا نمی‌کند. لطفاً در اپ ثبت‌نام را با شماره‌ای آغاز کنید که متعلق به همین حساب تلگرام است.',
                );
            }

            if ($contactVerified) {
                Cache::forget("telegram:registration:nonce:{$telegramUserId}");
                $telegram->sendMessage($chatId, 'شماره شما با موفقیت تأیید شد.');
            }
        } elseif (
            isset($message['text'])
            && $identity !== null
            && $identity->registration_draft_id !== null
            && $identity->phone_verification_status === 'Pending'
        ) {
            // A typed phone number is not proof of ownership. Re-show Telegram's
            // native share-contact button instead of silently ignoring the text.
            $telegram->requestContact($chatId);
        } elseif ($identity !== null) {
            $identity->forceFill(['chat_id' => $chatId, 'last_seen_at' => now()])->save();
        }

        $entry->forceFill(['processed_status' => 'Processed', 'processed_at' => now()])->save();
    }

    private function issuePasswordRecoveryOtp(
        string $nonce,
        int $telegramUserId,
        int $chatId,
        TelegramBotClient $telegram,
    ): void {
        $key = TelegramPasswordRecoveryController::cacheKey($nonce);
        $record = Cache::get($key);
        if (! is_array($record) || ($record['state'] ?? '') !== 'Pending') {
            $telegram->sendMessage($chatId, 'لینک بازیابی نامعتبر یا منقضی شده است.');

            return;
        }
        Cache::put(
            "telegram:password-recovery:contact:{$telegramUserId}",
            $nonce,
            \Illuminate\Support\Carbon::parse($record['expires_at'] ?? now()->addMinutes(10)),
        );
        $telegram->requestContact(
            $chatId,
            'برای تأیید مالکیت شمارهٔ ثبت‌شده، دکمهٔ «ارسال شماره موبایل» را بزنید. شماره فقط برای همین درخواست بازیابی بررسی می‌شود.',
        );
    }

    private function verifyPasswordRecoveryContact(
        string $nonce,
        int $telegramUserId,
        int $chatId,
        array $contact,
        TelegramBotClient $telegram,
    ): void {
        $key = TelegramPasswordRecoveryController::cacheKey($nonce);
        $record = Cache::get($key);
        $contactUserId = (int) ($contact['user_id'] ?? $contact['telegram_user_id'] ?? 0);
        $userId = (int) ($record['user_id'] ?? 0);
        $profile = $userId > 0 ? UserProfile::query()->whereKey($userId)->first() : null;
        $mobileMatches = false;
        $contactBelongsToSender = $contactUserId === $telegramUserId;
        $rejectionReason = 'profile_not_found';

        if (is_array($record) && ($record['state'] ?? '') === 'Pending'
            && $contactBelongsToSender && $profile !== null
            && is_string($profile->mobile_hash) && is_string($record['mobile_hash'] ?? null)) {
            try {
                $contactMobile = MobileNumber::normalize((string) ($contact['phone_number'] ?? ''));
                $contactHash = MobileIdentity::hash($contactMobile);
                $mobileMatches = hash_equals((string) $profile->mobile_hash, $contactHash)
                    && hash_equals((string) ($record['mobile_hash'] ?? ''), bin2hex($profile->mobile_hash));
                $rejectionReason = $mobileMatches ? 'telegram_identity_conflict' : 'contact_number_mismatch';
            } catch (\Throwable) {
                $mobileMatches = false;
                $rejectionReason = 'invalid_contact_number';
            }
        } elseif ($profile !== null && ! $contactBelongsToSender) {
            $rejectionReason = 'contact_not_owned_by_sender';
        } elseif ($profile === null) {
            $rejectionReason = 'profile_not_found';
        }

        $identityLinked = $mobileMatches
            && $profile !== null
            && $this->linkRecoveryTelegramIdentity($profile, $telegramUserId, $chatId);
        if (! $identityLinked) {
            logger()->notice('Telegram password recovery contact was rejected.', [
                'reason' => $rejectionReason,
                'profile_found' => $profile !== null,
                'contact_belongs_to_sender' => $contactBelongsToSender,
                'mobile_matches' => $mobileMatches,
            ]);
            Cache::forget("telegram:password-recovery:contact:{$telegramUserId}");
            if (is_array($record)) {
                Cache::put($key, [...$record, 'state' => 'Rejected'], now()->addMinutes(2));
            }
            $telegram->sendMessage(
                $chatId,
                'شمارهٔ ارسال‌شده با شمارهٔ ثبت‌شده برای این درخواست تطابق ندارد یا این حساب تلگرام به حساب دیگری متصل است. از اپ یک درخواست بازیابی تازه بسازید.',
            );

            return;
        }

        $identity = UserTelegramIdentity::query()
            ->where('telegram_user_id', $telegramUserId)
            ->where('user_id', $profile->user_id)
            ->where('phone_verification_status', 'Verified')
            ->firstOrFail();
        try {
            $otp = app(OtpService::class)->issueForUser(
                (int) $profile->user_id,
                (int) $identity->telegram_identity_id,
                'password_reset',
            );
        } catch (\Throwable) {
            Cache::forget("telegram:password-recovery:contact:{$telegramUserId}");
            Cache::put($key, [...$record, 'state' => 'Rejected'], now()->addMinutes(2));
            $telegram->sendMessage($chatId, 'درخواست ارسال کد انجام نشد. از اپ یک درخواست بازیابی تازه بسازید.');

            return;
        }
        Cache::forget("telegram:password-recovery:contact:{$telegramUserId}");
        Cache::put($key, [
            ...$record,
            'state' => 'OtpIssued',
            'otp_id' => $otp->otp_id,
        ], now()->addMinutes(2));
        $telegram->sendMessage($chatId, 'شماره تأیید شد و کد بازیابی به همین گفتگو ارسال شد. آن را در اپ وارد کنید.');
    }

    private function linkRecoveryTelegramIdentity(UserProfile $profile, int $telegramUserId, int $chatId): bool
    {
        return DB::transaction(function () use ($profile, $telegramUserId, $chatId): bool {
            $identity = UserTelegramIdentity::query()
                ->where('telegram_user_id', $telegramUserId)
                ->lockForUpdate()
                ->first();
            $chatIdentity = UserTelegramIdentity::query()
                ->where('chat_id', $chatId)
                ->lockForUpdate()
                ->first();

            if (($chatIdentity !== null && ($identity === null
                    || (int) $chatIdentity->telegram_identity_id !== (int) $identity->telegram_identity_id))
                || ($identity !== null && $identity->user_id !== null
                    && (int) $identity->user_id !== (int) $profile->user_id)
                || ($identity !== null
                    && $identity->registration_draft_id !== null
                    && ($identity->user_id === null
                        || (int) $identity->user_id !== (int) $profile->user_id))) {
                return false;
            }

            $identity ??= new UserTelegramIdentity();
            $identity->forceFill([
                'user_id' => $profile->user_id,
                'registration_draft_id' => null,
                'telegram_user_id' => $telegramUserId,
                'chat_id' => $chatId,
                'link_status' => 'Linked',
                'verified_mobile_hash' => $profile->mobile_hash,
                'phone_verified_at' => now(),
                'phone_verification_status' => 'Verified',
                'linked_at' => $identity->linked_at ?? now(),
                'last_seen_at' => now(),
            ])->save();

            return true;
        });
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
