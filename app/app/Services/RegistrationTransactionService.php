<?php

namespace App\Services;

use App\Models\RegistrationDraft;
use App\Models\Settlement;
use App\Models\UserAccount;
use App\Models\UserProfile;
use App\Models\UserTelegramIdentity;
use App\Support\MobileNumber;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use RuntimeException;

class RegistrationTransactionService
{
    public function createDraft(string $mobile, string $idempotencyKey): RegistrationDraft
    {
        $mobile = MobileNumber::normalize($mobile);
        $mobileHash = $this->hmac($mobile);

        return DB::transaction(function () use ($mobile, $mobileHash, $idempotencyKey): RegistrationDraft {
            $existing = RegistrationDraft::query()
                ->where('idempotency_key', $idempotencyKey)
                ->lockForUpdate()
                ->first();

            if ($existing !== null) {
                return $existing;
            }

            $active = RegistrationDraft::query()
                ->where('active_mobile_hash', $mobileHash)
                ->lockForUpdate()
                ->first();

            if ($active !== null && $active->expires_at->isFuture()) {
                return $active;
            }

            return RegistrationDraft::query()->create([
                'state_code' => 'Initiated',
                'step_code' => 'Mobile_Verification',
                'idempotency_key' => Str::limit($idempotencyKey, 80, ''),
                'mobile_hash' => $mobileHash,
                'mobile_encrypted' => Crypt::encryptString($mobile),
                'key_version' => (int) env('ENCRYPTION_KEY_VERSION', 1),
                'expires_at' => now()->addMinutes((int) env('REGISTRATION_DRAFT_TTL_MINUTES', 30)),
            ]);
        });
    }

    public function issueTelegramLinkNonce(RegistrationDraft|int $draft): string
    {
        return DB::transaction(function () use ($draft): string {
            $draft = $this->lockDraft($draft);
            $this->assertDraftOpen($draft);

            $nonce = rtrim(strtr(base64_encode(random_bytes(32)), '+/', '-_'), '=');
            $draft->forceFill([
                'telegram_link_nonce_hash' => hash('sha256', $nonce, true),
                'telegram_link_nonce_expires_at' => now()->addMinutes(
                    (int) env('TELEGRAM_LINK_NONCE_TTL_MINUTES', 10)
                ),
                'telegram_link_nonce_used_at' => null,
            ])->save();

            return $nonce;
        });
    }

    public function verifyTelegramContact(
        RegistrationDraft|int $draft,
        string $registrationNonce,
        array $telegram,
        array $contact
    ): UserTelegramIdentity {
        return DB::transaction(function () use ($draft, $registrationNonce, $telegram, $contact): UserTelegramIdentity {
            $draft = $this->lockDraft($draft);
            $this->assertDraftOpen($draft);

            if (
                $draft->telegram_link_nonce_used_at !== null
                || $draft->telegram_link_nonce_expires_at === null
                || $draft->telegram_link_nonce_expires_at->isPast()
                || $draft->telegram_link_nonce_hash === null
                || ! hash_equals($draft->telegram_link_nonce_hash, hash('sha256', $registrationNonce, true))
            ) {
                throw new RuntimeException('Invalid or expired registration nonce.');
            }

            $telegramUserId = (int) ($telegram['telegram_user_id'] ?? $telegram['user_id'] ?? 0);
            $chatId = (int) ($telegram['chat_id'] ?? 0);
            $contactUserId = (int) ($contact['user_id'] ?? $contact['telegram_user_id'] ?? 0);
            $contactPhone = MobileNumber::normalize((string) ($contact['phone_number'] ?? ''));
            $formMobile = MobileNumber::normalize(Crypt::decryptString($draft->mobile_encrypted));

            if ($telegramUserId <= 0 || $chatId === 0 || $contactUserId !== $telegramUserId) {
                throw new RuntimeException('Telegram Contact does not belong to the sender.');
            }
            if (! hash_equals($formMobile, $contactPhone)) {
                throw new RuntimeException('Telegram Contact does not match the registration mobile.');
            }

            $identity = UserTelegramIdentity::query()
                ->where('telegram_user_id', $telegramUserId)
                ->lockForUpdate()
                ->first();
            $chatIdentity = UserTelegramIdentity::query()
                ->where('chat_id', $chatId)
                ->lockForUpdate()
                ->first();

            if ($chatIdentity !== null && ($identity === null || $chatIdentity->telegram_identity_id !== $identity->telegram_identity_id)) {
                throw new RuntimeException('Telegram chat is already linked to another identity.');
            }
            if ($identity !== null && ($identity->user_id !== null || $identity->registration_draft_id !== null)
                && $identity->registration_draft_id !== $draft->registration_draft_id) {
                throw new RuntimeException('Telegram identity is already linked.');
            }

            $identity ??= new UserTelegramIdentity();
            $identity->forceFill([
                'registration_draft_id' => $draft->registration_draft_id,
                'user_id' => null,
                'telegram_user_id' => $telegramUserId,
                'chat_id' => $chatId,
                'username' => isset($telegram['username']) ? (string) $telegram['username'] : null,
                'link_status' => 'Linked',
                'verified_mobile_hash' => $draft->mobile_hash,
                'phone_verified_at' => now(),
                'phone_verification_status' => 'Verified',
                'linked_at' => now(),
                'last_seen_at' => now(),
            ])->save();

            $draft->forceFill(['telegram_link_nonce_used_at' => now()])->save();

            return $identity->refresh();
        });
    }

    public function selectNationalIdAndSettlement(
        RegistrationDraft|int $draft,
        string $nationalId,
        int $settlementCode
    ): RegistrationDraft {
        return DB::transaction(function () use ($draft, $nationalId, $settlementCode): RegistrationDraft {
            $draft = $this->lockDraft($draft);
            $this->assertDraftOpen($draft);
            $settlement = $this->validSettlementByCode($settlementCode);
            $nationalId = $this->normalizeNationalId($nationalId);

            $draft->forceFill([
                'national_id_hash' => $this->hmac($nationalId),
                'national_id_encrypted' => Crypt::encryptString($nationalId),
                'key_version' => (int) env('ENCRYPTION_KEY_VERSION', 1),
                'settlement_id' => $settlement->settlement_id,
                'step_code' => 'Password_Selection',
            ])->save();

            return $draft->refresh();
        });
    }

    public function completeRegistration(
        RegistrationDraft|int $draft,
        int $telegramIdentityId,
        string $password
    ): array {
        return DB::transaction(function () use ($draft, $telegramIdentityId, $password): array {
            $draft = $this->lockDraft($draft);
            $this->assertDraftOpen($draft);

            if (strlen($password) < 8) {
                throw new RuntimeException('Password must contain at least 8 characters.');
            }
            if ($draft->mobile_verified_at === null) {
                throw new RuntimeException('Mobile OTP verification is required before completion.');
            }
            if ($draft->national_id_hash === null || $draft->settlement_id === null) {
                throw new RuntimeException('National ID and settlement must be selected before completion.');
            }

            $identity = UserTelegramIdentity::query()
                ->whereKey($telegramIdentityId)
                ->where('registration_draft_id', $draft->registration_draft_id)
                ->where('phone_verification_status', 'Verified')
                ->lockForUpdate()
                ->firstOrFail();
            $settlement = $this->validSettlementById((int) $draft->settlement_id);

            $profile = UserProfile::query()->create([
                'mobile_hash' => $draft->mobile_hash,
                'mobile_encrypted' => $draft->mobile_encrypted,
                'national_id_hash' => $draft->national_id_hash,
                'national_id_encrypted' => $draft->national_id_encrypted,
                'settlement_id' => $settlement->settlement_id,
                'county_id' => $settlement->county->county_id,
                'province_id' => $settlement->county->province->province_id,
                'country_id' => $settlement->county->province->country->country_id,
                'is_active' => true,
                'created_at' => now(),
                'geo_updated_at' => now(),
                'initial_geo_selected_at' => now(),
            ]);

            $account = UserAccount::query()->create([
                'user_id' => $profile->user_id,
                'password_hash' => Hash::make($password),
                'account_status' => 'Active',
                'mfa_required' => false,
                'password_changed_at' => now(),
            ]);

            $identity->forceFill([
                'user_id' => $profile->user_id,
                'registration_draft_id' => null,
                'linked_at' => $identity->linked_at ?? now(),
                'last_seen_at' => now(),
            ])->save();
            $draft->forceFill([
                'state_code' => 'Completed',
                'step_code' => 'Final_Review',
                'completed_at' => now(),
                'telegram_link_nonce_hash' => null,
                'telegram_link_nonce_expires_at' => null,
                'telegram_link_nonce_used_at' => null,
            ])->save();

            return compact('draft', 'profile', 'account', 'identity');
        });
    }

    private function lockDraft(RegistrationDraft|int $draft): RegistrationDraft
    {
        return RegistrationDraft::query()
            ->whereKey($draft instanceof RegistrationDraft ? $draft->registration_draft_id : $draft)
            ->lockForUpdate()
            ->firstOrFail();
    }

    private function assertDraftOpen(RegistrationDraft $draft): void
    {
        if ($draft->state_code !== 'Initiated' || $draft->expires_at->isPast()) {
            throw new RuntimeException('Registration draft is not active.');
        }
    }

    private function validSettlementByCode(int $settlementCode): Settlement
    {
        $settlement = Settlement::query()
            ->active()
            ->where('settlement_code', $settlementCode)
            ->with('county.province.country')
            ->first();

        if (
            $settlement === null
            || ! $settlement->county->is_active
            || ! $settlement->county->province->is_active
            || ! $settlement->county->province->country->is_active
        ) {
            throw new RuntimeException('Settlement hierarchy is not active or valid.');
        }

        return $settlement;
    }

    private function validSettlementById(int $settlementId): Settlement
    {
        $settlement = Settlement::query()
            ->active()
            ->whereKey($settlementId)
            ->with('county.province.country')
            ->first();

        if (
            $settlement === null
            || ! $settlement->county->is_active
            || ! $settlement->county->province->is_active
            || ! $settlement->county->province->country->is_active
        ) {
            throw new RuntimeException('Settlement hierarchy is not active or valid.');
        }

        return $settlement;
    }

    private function normalizeNationalId(string $nationalId): string
    {
        $nationalId = preg_replace('/\D+/', '', $nationalId) ?? '';
        if (strlen($nationalId) !== 10) {
            throw new RuntimeException('Invalid national ID.');
        }

        return $nationalId;
    }

    private function hmac(string $value): string
    {
        $secret = (string) env('MOBILE_HMAC_SECRET');
        if ($secret === '') {
            throw new RuntimeException('MOBILE_HMAC_SECRET is not configured.');
        }

        return hash_hmac('sha256', $value, $secret, true);
    }
}
