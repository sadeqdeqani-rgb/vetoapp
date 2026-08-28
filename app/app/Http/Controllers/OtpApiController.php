<?php

namespace App\Http\Controllers;

use App\Models\Otp;
use App\Models\UserProfile;
use App\Services\OtpService;
use App\Support\MobileIdentity;
use App\Support\MobileNumber;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;

class OtpApiController extends Controller
{
    public function __construct(private readonly OtpService $otps) {}

    public function requestOtp(Request $request): JsonResponse
    {
        $data = $request->validate([
            'phone_number' => ['required', 'string'],
            'purpose' => ['required', 'in:registration,login,password_recovery,password_reset'],
            'registration_draft_id' => ['nullable', 'integer', 'min:1'],
            'telegram_identity_id' => ['nullable', 'integer', 'min:1'],
        ]);

        $mobile = $this->mobile($data['phone_number']);
        $purpose = $data['purpose'] === 'password_recovery'
            ? 'password_reset'
            : $data['purpose'];
        $identityId = (int) ($data['telegram_identity_id'] ?? 0);

        if ($purpose === 'registration') {
            if (! isset($data['registration_draft_id']) || $identityId <= 0) {
                throw ValidationException::withMessages([
                    'registration_draft_id' => [
                        'برای ثبت‌نام، draft و اتصال تأییدشده تلگرام لازم است.',
                    ],
                ]);
            }
            $otp = $this->otps->issueForRegistration(
                (int) $data['registration_draft_id'],
                $identityId,
            );
        } else {
            $profile = UserProfile::query()
                ->where('mobile_hash', MobileIdentity::hash($mobile))
                ->where('is_active', true)
                ->first();
            if ($profile === null || $identityId <= 0) {
                throw ValidationException::withMessages([
                    'phone_number' => ['حساب کاربری یا اتصال تلگرام معتبر نیست.'],
                ]);
            }
            $otp = $this->otps->issueForUser($profile->user_id, $identityId, $purpose);
        }

        return response()->json([
            'otp_id' => (string) $otp->otp_id,
            'expires_at' => $otp->expires_at?->toISOString(),
            'registration_draft_id' => $otp->registration_draft_id
                ? (string) $otp->registration_draft_id
                : null,
        ], 201);
    }

    public function verifyOtp(Request $request): JsonResponse
    {
        $data = $request->validate([
            'phone_number' => ['required', 'string'],
            'code' => ['required', 'digits:6'],
            'purpose' => ['required', 'in:registration,login,password_recovery,password_reset'],
            'otp_id' => ['nullable', 'integer', 'min:1'],
        ]);

        $mobile = $this->mobile($data['phone_number']);
        $purpose = $data['purpose'] === 'password_recovery'
            ? 'password_reset'
            : $data['purpose'];
        $query = Otp::query()
            ->where('mobile_hash', MobileIdentity::hash($mobile))
            ->where('purpose', $purpose)
            ->where('state', 'Issued');

        if (isset($data['otp_id'])) {
            $query->whereKey((int) $data['otp_id']);
        }

        $otp = $query->latest('otp_id')->firstOrFail();
        $verified = $this->otps->verify($data['code'], $otp->otp_id);
        $token = Crypt::encryptString(json_encode([
            'otp_id' => $verified->otp_id,
            'user_id' => $verified->user_id,
            'purpose' => $verified->purpose,
            'verified_at' => now()->timestamp,
        ], JSON_THROW_ON_ERROR));

        return response()->json([
            'otp_id' => (string) $verified->otp_id,
            'verification_token' => $token,
            'registration_draft_id' => $verified->registration_draft_id
                ? (string) $verified->registration_draft_id
                : null,
        ]);
    }

    public function resetPassword(Request $request): JsonResponse
    {
        $data = $request->validate([
            'phone_number' => ['required', 'string'],
            'verification_token' => ['required', 'string'],
            'new_password' => ['required', 'string', 'min:8', 'max:255'],
        ]);
        $payload = json_decode(Crypt::decryptString($data['verification_token']), true);
        $mobile = $this->mobile($data['phone_number']);
        $profile = UserProfile::query()
            ->where('mobile_hash', MobileIdentity::hash($mobile))
            ->whereKey((int) ($payload['user_id'] ?? 0))
            ->firstOrFail();
        $otp = Otp::query()
            ->whereKey((int) ($payload['otp_id'] ?? 0))
            ->where('user_id', $profile->user_id)
            ->where('purpose', 'password_reset')
            ->where('state', 'Verified')
            ->firstOrFail();

        $profile->account()->update([
            'password_hash' => Hash::make($data['new_password']),
            'password_reset_completed_at' => now(),
            'password_changed_at' => now(),
            'failed_login_count' => 0,
            'locked_until' => null,
            'updated_at' => now(),
        ]);

        return response()->json(['message' => 'رمز عبور با موفقیت تغییر کرد.']);
    }

    private function mobile(string $value): string
    {
        try {
            return MobileNumber::normalize($value);
        } catch (\InvalidArgumentException) {
            throw ValidationException::withMessages([
                'phone_number' => ['شماره موبایل معتبر نیست.'],
            ]);
        }
    }
}
