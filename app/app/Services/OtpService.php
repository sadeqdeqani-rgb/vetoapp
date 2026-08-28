<?php

namespace App\Services;

use App\Jobs\TelegramSendMessageJob;
use App\Models\Otp;
use App\Models\OtpDeliveryAttempt;
use App\Models\OtpThrottleWindow;
use App\Models\RegistrationDraft;
use App\Models\UserProfile;
use App\Models\UserTelegramIdentity;
use App\Support\OtpCodeHasher;
use Illuminate\Contracts\Cache\LockTimeoutException;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\DB;
use RuntimeException;

class OtpService
{
    public function issueForRegistration(RegistrationDraft|int $draft, int $telegramIdentityId): Otp
    {
        $draftId = $draft instanceof RegistrationDraft ? $draft->registration_draft_id : $draft;

        return $this->withMobileLock($draftId, function () use ($draftId, $telegramIdentityId): Otp {
            return DB::transaction(function () use ($draftId, $telegramIdentityId): Otp {
                $draft = RegistrationDraft::query()->whereKey($draftId)->lockForUpdate()->firstOrFail();
                $identity = UserTelegramIdentity::query()
                    ->whereKey($telegramIdentityId)
                    ->where('registration_draft_id', $draft->registration_draft_id)
                    ->where('phone_verification_status', 'Verified')
                    ->lockForUpdate()
                    ->firstOrFail();

                if ($draft->state_code !== 'Initiated' || $draft->expires_at->isPast()
                    || ! hash_equals($draft->mobile_hash, $identity->verified_mobile_hash)) {
                    throw new RuntimeException('Registration OTP destination is invalid.');
                }

                $window = $this->openThrottleWindow($draft);
                $this->assertCanSend($window);
                $this->expirePrevious($draft->mobile_hash, 'registration', $draft->registration_draft_id);

                $code = (string) random_int(100000, 999999);
                $nonce = random_bytes(16);
                $otp = Otp::query()->create([
                    'mobile_hash' => $draft->mobile_hash,
                    'mobile_encrypted' => $draft->mobile_encrypted,
                    'purpose' => 'registration',
                    'otp_nonce' => $nonce,
                    'code_hash' => OtpCodeHasher::hash($code, 'registration', $draft->mobile_hash, $nonce),
                    'state' => 'Issued',
                    'issued_at' => now(),
                    'expires_at' => now()->addMinutes(2),
                    'attempt_count' => 0,
                    'max_attempt_count' => 3,
                    'delivery_channel' => 'telegram_bot',
                    'registration_draft_id' => $draft->registration_draft_id,
                    'otp_throttle_window_id' => $window->otp_throttle_window_id,
                ]);

                $window->increment('send_count');
                $window->forceFill(['last_sent_at' => now(), 'updated_at' => now()])->save();
                $attempt = OtpDeliveryAttempt::query()->create([
                    'otp_id' => $otp->otp_id,
                    'telegram_identity_id' => $identity->telegram_identity_id,
                    'channel' => 'telegram_bot',
                    'attempt_number' => 1,
                    'status' => 'Queued',
                    'attempted_at' => now(),
                    'created_at' => now(),
                ]);

                TelegramSendMessageJob::dispatch(
                    $attempt->delivery_attempt_id,
                    Crypt::encryptString($code)
                )->afterCommit();

                // The raw code is never returned or persisted.
                return $otp;
            });
        });
    }

    public function issueForUser(int $userId, int $telegramIdentityId, string $purpose): Otp
    {
        return DB::transaction(function () use ($userId, $telegramIdentityId, $purpose): Otp {
            $profile = UserProfile::query()
                ->whereKey($userId)
                ->where('is_active', true)
                ->firstOrFail();
            $identity = UserTelegramIdentity::query()
                ->whereKey($telegramIdentityId)
                ->where('user_id', $userId)
                ->where('phone_verification_status', 'Verified')
                ->firstOrFail();

            $window = $this->openUserThrottleWindow($profile);
            $this->assertCanSend($window);
            $this->expirePrevious($profile->mobile_hash, $purpose, null);

            $code = (string) random_int(100000, 999999);
            $nonce = random_bytes(16);
            $otp = Otp::query()->create([
                'mobile_hash' => $profile->mobile_hash,
                'mobile_encrypted' => $profile->mobile_encrypted,
                'purpose' => $purpose,
                'otp_nonce' => $nonce,
                'code_hash' => OtpCodeHasher::hash($code, $purpose, $profile->mobile_hash, $nonce),
                'state' => 'Issued',
                'issued_at' => now(),
                'expires_at' => now()->addMinutes(2),
                'attempt_count' => 0,
                'max_attempt_count' => 3,
                'delivery_channel' => 'telegram_bot',
                'user_id' => $userId,
                'otp_throttle_window_id' => $window->otp_throttle_window_id,
            ]);

            $window->increment('send_count');
            $window->forceFill(['last_sent_at' => now(), 'updated_at' => now()])->save();
            $attempt = OtpDeliveryAttempt::query()->create([
                'otp_id' => $otp->otp_id,
                'telegram_identity_id' => $identity->telegram_identity_id,
                'channel' => 'telegram_bot',
                'attempt_number' => 1,
                'status' => 'Queued',
                'attempted_at' => now(),
                'created_at' => now(),
            ]);

            TelegramSendMessageJob::dispatch(
                $attempt->delivery_attempt_id,
                Crypt::encryptString($code)
            )->afterCommit();

            return $otp;
        });
    }

    public function verify(string $code, int $otpId): Otp
    {
        return DB::transaction(function () use ($code, $otpId): Otp {
            $otp = Otp::query()->whereKey($otpId)->lockForUpdate()->firstOrFail();
            if ($otp->state !== 'Issued' || $otp->expires_at->isPast()) {
                $otp->forceFill(['state' => 'Expired'])->save();
                throw new RuntimeException('OTP is expired or unavailable.');
            }
            if ($otp->attempt_count >= $otp->max_attempt_count) {
                $otp->forceFill(['state' => 'Failed', 'failed_at' => now()])->save();
                throw new RuntimeException('OTP attempt limit reached.');
            }

            $expected = OtpCodeHasher::hash($code, $otp->purpose, $otp->mobile_hash, $otp->otp_nonce);
            if (! hash_equals($otp->code_hash, $expected)) {
                $otp->increment('attempt_count');
                $otp->refresh();
                if ($otp->attempt_count >= $otp->max_attempt_count) {
                    $otp->forceFill(['state' => 'Failed', 'failed_at' => now()])->save();
                }
                $window = OtpThrottleWindow::query()
                    ->whereKey($otp->otp_throttle_window_id)
                    ->lockForUpdate()
                    ->first();
                if ($window !== null) {
                    $window->increment('verify_failed_count');
                    $window->refresh();
                    if ($window->verify_failed_count >= 5) {
                        $window->forceFill([
                            'state' => 'Blocked',
                            'blocked_until' => now()->addMinutes(60),
                        ])->save();
                        Otp::query()
                            ->where('otp_throttle_window_id', $window->otp_throttle_window_id)
                            ->where('state', 'Issued')
                            ->update(['state' => 'Failed', 'failed_at' => now(), 'updated_at' => now()]);
                    }
                }
                throw new RuntimeException('Invalid OTP.');
            }

            $otp->forceFill(['state' => 'Verified', 'verified_at' => now()])->save();
            if ($otp->purpose === 'registration' && $otp->registration_draft_id !== null) {
                RegistrationDraft::query()
                    ->whereKey($otp->registration_draft_id)
                    ->where('state_code', 'Initiated')
                    ->update([
                        'mobile_verified_at' => now(),
                        'step_code' => 'National_ID_Verification',
                        'updated_at' => now(),
                    ]);
            }

            return $otp->refresh();
        });
    }

    private function openThrottleWindow(RegistrationDraft $draft): OtpThrottleWindow
    {
        $window = OtpThrottleWindow::query()
            ->where('mobile_hash', $draft->mobile_hash)
            ->whereIn('state', ['Open', 'Throttled', 'Blocked'])
            ->latest('otp_throttle_window_id')
            ->lockForUpdate()
            ->first();

        if ($window !== null && $window->window_ends_at->isFuture()) {
            return $window;
        }

        return OtpThrottleWindow::query()->create([
            'mobile_hash' => $draft->mobile_hash,
            'mobile_encrypted' => $draft->mobile_encrypted,
            'window_started_at' => now(),
            'window_ends_at' => now()->addMinutes(15),
            'send_count' => 0,
            'verify_failed_count' => 0,
            'state' => 'Open',
            'penalty_tier' => 0,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    private function assertCanSend(OtpThrottleWindow $window): void
    {
        if ($window->state === 'Blocked' && $window->blocked_until?->isFuture()) {
            throw new RuntimeException('OTP temporarily blocked.');
        }
        if ($window->last_sent_at !== null && $window->last_sent_at->diffInSeconds(now()) < 60) {
            throw new RuntimeException('OTP send cooldown is active.');
        }
        if ($window->send_count >= 3) {
            $window->forceFill([
                'state' => 'Throttled',
                'throttled_until' => now()->addMinutes(15),
            ])->save();
            throw new RuntimeException('OTP send limit reached.');
        }
    }

    private function expirePrevious(string $mobileHash, string $purpose, ?int $draftId): void
    {
        $query = Otp::query()
            ->where('mobile_hash', $mobileHash)
            ->where('purpose', $purpose)
            ->where('state', 'Issued');

        if ($draftId === null) {
            $query->whereNull('registration_draft_id');
        } else {
            $query->where('registration_draft_id', $draftId);
        }

        $query->update(['state' => 'Expired', 'updated_at' => now()]);
    }

    private function openUserThrottleWindow(UserProfile $profile): OtpThrottleWindow
    {
        $window = OtpThrottleWindow::query()
            ->where('mobile_hash', $profile->mobile_hash)
            ->whereIn('state', ['Open', 'Throttled', 'Blocked'])
            ->latest('otp_throttle_window_id')
            ->lockForUpdate()
            ->first();

        if ($window !== null && $window->window_ends_at->isFuture()) {
            return $window;
        }

        return OtpThrottleWindow::query()->create([
            'mobile_hash' => $profile->mobile_hash,
            'mobile_encrypted' => $profile->mobile_encrypted,
            'window_started_at' => now(),
            'window_ends_at' => now()->addMinutes(15),
            'send_count' => 0,
            'verify_failed_count' => 0,
            'state' => 'Open',
            'penalty_tier' => 0,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    private function withMobileLock(int $draftId, callable $callback): Otp
    {
        $draft = RegistrationDraft::query()->findOrFail($draftId);
        $lock = Cache::lock('otp:mobile:'.bin2hex($draft->mobile_hash), 10);
        try {
            return $lock->block(5, $callback);
        } catch (LockTimeoutException) {
            throw new RuntimeException('OTP request is already being processed.');
        } finally {
            optional($lock)->release();
        }
    }
}
