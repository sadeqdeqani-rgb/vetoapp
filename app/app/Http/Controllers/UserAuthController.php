<?php

namespace App\Http\Controllers;

use App\Models\AuthSession;
use App\Models\UserProfile;
use App\Support\MobileIdentity;
use App\Support\MobileNumber;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

class UserAuthController extends Controller
{
    public function login(Request $request): JsonResponse
    {
        $data = $request->validate([
            'phone_number' => ['required', 'string'],
            'password' => ['required', 'string', 'max:255'],
        ]);

        try {
            $mobile = MobileNumber::normalize($data['phone_number']);
        } catch (\InvalidArgumentException) {
            throw ValidationException::withMessages([
                'phone_number' => ['شماره موبایل معتبر نیست.'],
            ]);
        }

        $profile = UserProfile::query()
            ->where('mobile_hash', MobileIdentity::hash($mobile))
            ->where('is_active', true)
            ->with('account')
            ->first();
        $account = $profile?->account;

        if ($profile === null || $account === null) {
            throw ValidationException::withMessages([
                'phone_number' => ['شماره موبایل یا رمز عبور صحیح نیست.'],
            ]);
        }

        if ($account->account_status !== 'Active'
            || ($account->locked_until !== null && $account->locked_until->isFuture())) {
            return response()->json(['message' => 'حساب کاربری موقتاً قفل است.'], 423);
        }

        if (! Hash::check($data['password'], (string) $account->password_hash)) {
            DB::table('user_accounts')
                ->where('user_id', $profile->user_id)
                ->update([
                    'failed_login_count' => DB::raw('failed_login_count + 1'),
                    'last_failed_login_at' => now(),
                    'updated_at' => now(),
                ]);
            $this->auditLogin($profile->user_id, 'Failed', 'INVALID_CREDENTIALS', $request);

            throw ValidationException::withMessages([
                'phone_number' => ['شماره موبایل یا رمز عبور صحیح نیست.'],
            ]);
        }

        return DB::transaction(function () use ($profile, $request): JsonResponse {
            AuthSession::query()
                ->where('user_id', $profile->user_id)
                ->where('state', 'Active')
                ->update([
                    'state' => 'Revoked',
                    'revoked_at' => now(),
                    'terminated_at' => now(),
                    'terminal_reason' => 'force_revocation',
                    'updated_at' => now(),
                ]);

            $sessionUuid = (string) Str::uuid();
            $session = AuthSession::query()->create([
                'session_uuid' => hex2bin(str_replace('-', '', $sessionUuid)),
                'user_id' => $profile->user_id,
                'authentication_method' => 'Password',
                'state' => 'Active',
                'ip_address' => $request->ip() ?? '0.0.0.0',
                'user_agent' => substr((string) $request->userAgent(), 0, 512),
                'issued_at' => now(),
                'last_activity_at' => now(),
                'expires_at' => now()->addDays((int) config('auth.user_session_days', 30)),
                'created_at' => now(),
                'updated_at' => now(),
            ]);

            $this->auditLogin($profile->user_id, 'Success', null, $request);

            return response()->json([
                'session_token' => $sessionUuid,
                'user_id' => (string) $profile->user_id,
                'expires_at' => $session->expires_at?->toISOString(),
            ]);
        });
    }

    public function logout(Request $request): JsonResponse
    {
        /** @var AuthSession $session */
        $session = $request->attributes->get('auth_session');
        $session->forceFill([
            'state' => 'LoggedOut',
            'logged_out_at' => now(),
            'terminated_at' => now(),
            'terminal_reason' => 'manual_logout',
        ])->save();

        return response()->json(['message' => 'نشست کاربر خاتمه یافت.']);
    }

    public function heartbeat(Request $request): JsonResponse
    {
        $data = $request->validate([
            'foreground_interaction' => ['required', 'boolean'],
        ]);

        /** @var AuthSession $session */
        $session = $request->attributes->get('auth_session');
        if (! $data['foreground_interaction']) {
            return response()->json([
                'data' => [
                    'accepted' => false,
                    'last_activity_at' => $session->last_activity_at?->toISOString(),
                ],
            ]);
        }

        $now = now();
        $updated = AuthSession::query()
            ->whereKey($session->getKey())
            ->where('state', 'Active')
            ->where('expires_at', '>', $now)
            ->where('last_activity_at', '>', $now->copy()->subMinutes(15))
            ->update(['last_activity_at' => $now, 'updated_at' => $now]);

        if ($updated !== 1) {
            return response()->json(['message' => 'نشست کاربر منقضی یا غیرفعال است.'], 401);
        }

        return response()->json([
            'data' => [
                'accepted' => true,
                'last_activity_at' => $now->toISOString(),
            ],
        ]);
    }

    private function auditLogin(
        int $userId,
        string $status,
        ?string $reason,
        Request $request
    ): void {
        DB::table('user_login_audit_logs')->insert([
            'user_id' => $userId,
            'attempted_at' => now(),
            'login_status' => $status,
            'failure_reason' => $reason,
            'ip_address' => $request->ip() ?? '0.0.0.0',
            'user_agent' => substr((string) $request->userAgent(), 0, 512),
        ]);
    }
}
