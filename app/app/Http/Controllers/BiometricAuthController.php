<?php

namespace App\Http\Controllers;

use App\Models\AuthSession;
use App\Models\UserProfile;
use App\Support\MobileIdentity;
use App\Support\MobileNumber;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\Str;

class BiometricAuthController extends Controller
{
    private const CHALLENGE_TTL_MINUTES = 5;

    public function status(Request $request): JsonResponse
    {
        $userId = (int) $request->attributes->get('user_profile')->user_id;
        $credential = DB::table('user_biometric_credentials')
            ->where('user_id', $userId)
            ->where('is_active', true)
            ->first(['device_model', 'created_at', 'last_used_at']);

        return response()->json(['data' => [
            'enabled' => $credential !== null,
            'device_model' => $credential?->device_model,
            'created_at' => $credential?->created_at,
            'last_used_at' => $credential?->last_used_at,
        ]]);
    }

    public function enrollmentChallenge(Request $request): JsonResponse
    {
        $userId = (int) $request->attributes->get('user_profile')->user_id;
        if ($this->rateLimited('biometric-enroll:'.$userId, 10)) {
            return response()->json(['message' => 'تعداد درخواست‌ها زیاد است؛ کمی بعد دوباره تلاش کنید.'], 429);
        }
        $credentialId = (string) Str::uuid();
        $challenge = random_bytes(32);
        $challengeId = (string) Str::uuid();
        $now = now();

        $this->pruneExpiredChallenges();
        DB::table('user_biometric_challenges')->insert([
            'challenge_id' => $challengeId,
            'user_id' => $userId,
            'credential_id' => $this->uuidToBinary($credentialId),
            'purpose' => 'enroll',
            'challenge' => $challenge,
            'expires_at' => $now->copy()->addMinutes(self::CHALLENGE_TTL_MINUTES),
            'created_at' => $now,
        ]);

        return response()->json(['data' => $this->challengePayload(
            $challengeId,
            'enroll',
            $challenge,
            $credentialId,
        )]);
    }

    public function enroll(Request $request): JsonResponse
    {
        $data = $request->validate([
            'challenge_id' => ['required', 'uuid'],
            'credential_id' => ['required', 'uuid'],
            'public_key' => ['required', 'string', 'max:2048'],
            'signature' => ['required', 'string', 'max:2048'],
            'device_model' => ['nullable', 'string', 'max:100'],
        ]);
        $userId = (int) $request->attributes->get('user_profile')->user_id;
        if ($this->rateLimited('biometric-enroll:'.$userId, 10)) {
            return response()->json(['message' => 'تعداد درخواست‌ها زیاد است؛ کمی بعد دوباره تلاش کنید.'], 429);
        }

        $result = DB::transaction(function () use ($data, $request, $userId): bool {
            $challenge = DB::table('user_biometric_challenges')
                ->where('challenge_id', $data['challenge_id'])
                ->lockForUpdate()
                ->first();
            $credentialBinary = $this->uuidToBinary($data['credential_id']);

            if ($challenge === null
                || $challenge->purpose !== 'enroll'
                || (int) $challenge->user_id !== $userId
                || ! hash_equals((string) $challenge->credential_id, $credentialBinary)
                || $challenge->consumed_at !== null
                || now()->greaterThanOrEqualTo($challenge->expires_at)) {
                return false;
            }

            // Consume before checking the signature so failed attempts cannot
            // reuse the same enrollment challenge.
            DB::table('user_biometric_challenges')->where('challenge_id', $data['challenge_id'])
                ->update(['consumed_at' => now()]);

            $publicKey = $this->decodeBase64Url($data['public_key']);
            $signature = $this->decodeBase64Url($data['signature']);
            if ($publicKey === null || $signature === null || strlen($publicKey) > 600) {
                return false;
            }

            $payload = $this->signedPayload(
                'enroll',
                $data['challenge_id'],
                (string) $challenge->challenge,
            );
            if (! $this->verifySignature($publicKey, $signature, $payload)) {
                return false;
            }

            $now = now();
            DB::table('user_biometric_credentials')
                ->where('user_id', $userId)
                ->where('is_active', true)
                ->update(['is_active' => false, 'is_default' => false, 'updated_at' => $now]);

            DB::table('user_biometric_credentials')->insert([
                'user_id' => $userId,
                'credential_id' => $credentialBinary,
                'device_identifier' => hash('sha256', $credentialBinary),
                'device_model' => $data['device_model'] ?? substr((string) $request->header('User-Agent'), 0, 100),
                'public_key' => $publicKey,
                'public_key_sha256' => hash('sha256', $publicKey, true),
                'key_algorithm' => 'ES256',
                'is_active' => true,
                'is_default' => true,
                'sign_count' => 0,
                'created_at' => $now,
                'updated_at' => $now,
            ]);

            return true;
        });

        if (! $result) {
            return response()->json(['message' => 'ثبت ورود بیومتریک انجام نشد؛ دوباره تلاش کنید.'], 422);
        }

        return response()->json(['data' => ['enabled' => true]], 201);
    }

    public function loginChallenge(Request $request): JsonResponse
    {
        $data = $request->validate(['phone_number' => ['required', 'string', 'max:32']]);
        try {
            $rateIdentity = MobileNumber::normalize($data['phone_number']);
        } catch (\InvalidArgumentException) {
            $rateIdentity = trim($data['phone_number']);
        }
        if ($this->rateLimited('biometric-login:'.hash('sha256', $rateIdentity), 10)) {
            return response()->json(['message' => 'تعداد درخواست‌ها زیاد است؛ کمی بعد دوباره تلاش کنید.'], 429);
        }
        $challengeId = (string) Str::uuid();
        $rawChallenge = random_bytes(32);
        $credential = null;

        try {
            $mobile = MobileNumber::normalize($data['phone_number']);
            $profile = UserProfile::query()
                ->where('mobile_hash', MobileIdentity::hash($mobile))
                ->where('is_active', true)
                ->with('account')
                ->first();
            if ($profile?->account?->account_status === 'Active') {
                $credential = DB::table('user_biometric_credentials')
                    ->where('user_id', $profile->user_id)
                    ->where('is_active', true)
                    ->first(['credential_id']);
            }
        } catch (\InvalidArgumentException) {
            // Keep the response shape the same for unknown/invalid phone numbers.
        }

        $now = now();
        $this->pruneExpiredChallenges();
        DB::table('user_biometric_challenges')->insert([
            'challenge_id' => $challengeId,
            'user_id' => $credential === null ? null : $profile->user_id,
            'credential_id' => $credential?->credential_id,
            'purpose' => 'login',
            'challenge' => $rawChallenge,
            'expires_at' => $now->copy()->addMinutes(self::CHALLENGE_TTL_MINUTES),
            'created_at' => $now,
        ]);

        return response()->json(['data' => $this->challengePayload(
            $challengeId,
            'login',
            $rawChallenge,
            null,
        )]);
    }

    public function verifyLogin(Request $request): JsonResponse
    {
        $data = $request->validate([
            'challenge_id' => ['required', 'uuid'],
            'credential_id' => ['required', 'uuid'],
            'signature' => ['required', 'string', 'max:2048'],
        ]);

        $challengeOwner = DB::table('user_biometric_challenges')
            ->where('challenge_id', $data['challenge_id'])
            ->value('user_id');
        $verifyKey = $challengeOwner === null
            ? 'biometric-verify:'.hash('sha256', $data['challenge_id'])
            : 'biometric-verify-user:'.$challengeOwner;
        if ($this->rateLimited($verifyKey, 10)) {
            return response()->json(['message' => 'تعداد درخواست‌ها زیاد است؛ کمی بعد دوباره تلاش کنید.'], 429);
        }

        $result = DB::transaction(function () use ($data, $request): ?JsonResponse {
            $challenge = DB::table('user_biometric_challenges')
                ->where('challenge_id', $data['challenge_id'])
                ->lockForUpdate()
                ->first();
            $credentialBinary = $this->uuidToBinary($data['credential_id']);

            if ($challenge === null
                || $challenge->purpose !== 'login'
                || $challenge->user_id === null
                || $challenge->credential_id === null
                || ! hash_equals((string) $challenge->credential_id, $credentialBinary)
                || $challenge->consumed_at !== null
                || now()->greaterThanOrEqualTo($challenge->expires_at)) {
                return null;
            }

            DB::table('user_biometric_challenges')->where('challenge_id', $data['challenge_id'])
                ->update(['consumed_at' => now()]);

            $credential = DB::table('user_biometric_credentials')
                ->where('user_id', $challenge->user_id)
                ->where('credential_id', $credentialBinary)
                ->where('is_active', true)
                ->first();
            $profile = UserProfile::query()->whereKey($challenge->user_id)
                ->where('is_active', true)->with('account')->first();
            $signature = $this->decodeBase64Url($data['signature']);
            $payload = $this->signedPayload('login', $data['challenge_id'], (string) $challenge->challenge);

            if ($credential === null
                || $profile?->account?->account_status !== 'Active'
                || ($profile->account->locked_until !== null && $profile->account->locked_until->isFuture())
                || $signature === null
                || ! $this->verifySignature((string) $credential->public_key, $signature, $payload)) {
                return null;
            }

            $now = now();
            AuthSession::query()->where('user_id', $profile->user_id)->where('state', 'Active')->update([
                'state' => 'Revoked', 'revoked_at' => $now, 'terminated_at' => $now,
                'terminal_reason' => 'force_revocation', 'updated_at' => $now,
            ]);

            $sessionUuid = (string) Str::uuid();
            $session = AuthSession::query()->create([
                'session_uuid' => hex2bin(str_replace('-', '', $sessionUuid)),
                'user_id' => $profile->user_id,
                'authentication_method' => 'Biometric',
                'state' => 'Active',
                'ip_address' => $request->ip() ?? '0.0.0.0',
                'user_agent' => substr((string) $request->userAgent(), 0, 512),
                'issued_at' => $now,
                'last_activity_at' => $now,
                'expires_at' => $now->copy()->addDays((int) config('auth.user_session_days', 30)),
                'created_at' => $now,
                'updated_at' => $now,
            ]);

            DB::table('user_biometric_credentials')->where('biometric_credential_id', $credential->biometric_credential_id)
                ->increment('sign_count', 1, ['last_used_at' => $now, 'updated_at' => $now]);
            DB::table('user_login_audit_logs')->insert([
                'user_id' => $profile->user_id, 'attempted_at' => $now, 'login_status' => 'Success',
                'failure_reason' => null, 'ip_address' => $request->ip() ?? '0.0.0.0',
                'user_agent' => substr((string) $request->userAgent(), 0, 512),
            ]);

            return response()->json([
                'session_token' => $sessionUuid,
                'user_id' => (string) $profile->user_id,
                'expires_at' => $session->expires_at?->toISOString(),
            ]);
        });

        if ($result === null) {
            return response()->json(['message' => 'احراز هویت بیومتریک انجام نشد.'], 401);
        }

        return $result;
    }

    public function revoke(Request $request): JsonResponse
    {
        $userId = (int) $request->attributes->get('user_profile')->user_id;
        DB::table('user_biometric_credentials')->where('user_id', $userId)->where('is_active', true)->update([
            'is_active' => false, 'is_default' => false, 'updated_at' => now(),
        ]);

        return response()->json(['data' => ['enabled' => false]]);
    }

    private function challengePayload(string $id, string $purpose, string $challenge, ?string $credentialId): array
    {
        return [
            'challenge_id' => $id,
            'challenge' => $this->base64UrlEncode($challenge),
            'credential_id' => $credentialId,
            'signed_payload' => $this->signedPayload($purpose, $id, $challenge),
        ];
    }

    private function signedPayload(string $purpose, string $challengeId, string $challenge): string
    {
        return 'vetoapp-biometric-v1|'.$purpose.'|'.$challengeId.'|'.$this->base64UrlEncode($challenge);
    }

    private function verifySignature(string $publicKeyDer, string $signature, string $payload): bool
    {
        $pem = "-----BEGIN PUBLIC KEY-----\n".chunk_split(base64_encode($publicKeyDer), 64, "\n")."-----END PUBLIC KEY-----\n";
        $key = openssl_pkey_get_public($pem);
        if ($key === false) return false;
        $details = openssl_pkey_get_details($key);
        if (($details['type'] ?? null) !== OPENSSL_KEYTYPE_EC
            || ! in_array($details['ec']['curve_name'] ?? '', ['prime256v1', 'P-256'], true)) {
            return false;
        }

        return openssl_verify($payload, $signature, $key, OPENSSL_ALGO_SHA256) === 1;
    }

    private function uuidToBinary(string $uuid): string
    {
        return hex2bin(str_replace('-', '', $uuid)) ?: '';
    }

    private function base64UrlEncode(string $value): string
    {
        return rtrim(strtr(base64_encode($value), '+/', '-_'), '=');
    }

    private function decodeBase64Url(string $value): ?string
    {
        $padded = strtr($value, '-_', '+/');
        $decoded = base64_decode($padded.str_repeat('=', (4 - strlen($padded) % 4) % 4), true);
        return $decoded === false ? null : $decoded;
    }

    private function pruneExpiredChallenges(): void
    {
        DB::table('user_biometric_challenges')
            ->where('expires_at', '<', now()->subDay())
            ->delete();
    }

    private function rateLimited(string $key, int $maximumAttempts): bool
    {
        if (RateLimiter::tooManyAttempts($key, $maximumAttempts)) {
            return true;
        }

        RateLimiter::hit($key, 60);
        return false;
    }
}
