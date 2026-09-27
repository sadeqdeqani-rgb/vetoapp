<?php

namespace App\Http\Controllers;

use App\Models\UserProfile;
use App\Models\UserTelegramIdentity;
use App\Support\MobileIdentity;
use App\Support\MobileNumber;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

class TelegramPasswordRecoveryController extends Controller
{
    public function start(Request $request): JsonResponse
    {
        $data = $request->validate(['phone_number' => ['required', 'string']]);

        try {
            $mobile = MobileNumber::normalize($data['phone_number']);
        } catch (\InvalidArgumentException) {
            throw ValidationException::withMessages([
                'phone_number' => ['شماره موبایل معتبر نیست.'],
            ]);
        }

        $nonce = Str::replace('/', '_', Str::replace('+', '-', base64_encode(random_bytes(32))));
        $nonce = rtrim($nonce, '=');
        $expiresAt = now()->addMinutes((int) env('TELEGRAM_LINK_NONCE_TTL_MINUTES', 10));
        $profile = UserProfile::query()
            ->where('mobile_hash', MobileIdentity::hash($mobile))
            ->where('is_active', true)
            ->first();
        $identity = $profile === null ? null : UserTelegramIdentity::query()
            ->where('user_id', $profile->user_id)
            ->where('phone_verification_status', 'Verified')
            ->first();

        Cache::put($this->cacheKey($nonce), [
            'user_id' => $identity?->user_id,
            'telegram_identity_id' => $identity?->telegram_identity_id,
            'state' => 'Pending',
            'expires_at' => $expiresAt->toISOString(),
        ], $expiresAt);

        $username = trim((string) config('services.telegram.bot_username'));

        return response()->json([
            'state' => 'Pending',
            'expires_at' => $expiresAt->toISOString(),
            'telegram_start_url' => $username === '' ? null : "https://t.me/{$username}?start=reset-{$nonce}",
        ], 201);
    }

    public function status(Request $request): JsonResponse
    {
        $data = $request->validate(['nonce' => ['required', 'string', 'max:128']]);
        $record = Cache::get($this->cacheKey($data['nonce']));
        if (! is_array($record)) {
            return response()->json(['message' => 'لینک بازیابی منقضی یا نامعتبر است.'], 410);
        }

        return response()->json([
            'state' => $record['state'] ?? 'Pending',
            'otp_id' => isset($record['otp_id']) ? (string) $record['otp_id'] : null,
            'expires_at' => $record['expires_at'] ?? null,
        ]);
    }

    public static function cacheKey(string $nonce): string
    {
        return 'telegram:password-recovery:'.hash('sha256', $nonce);
    }
}
