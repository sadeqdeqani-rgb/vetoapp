<?php

namespace App\Http\Controllers;

use App\Models\AuthSession;
use App\Models\UserAccount;
use App\Models\UserProfile;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\DB;

class ProfileController extends Controller
{
    public function show(Request $request): JsonResponse
    {
        /** @var UserProfile $profile */
        $profile = $request->attributes->get('user_profile');
        $profile->loadMissing('account');

        return response()->json([
            'data' => [
                'user_id' => (string) $profile->user_id,
                'phone_number' => $this->decrypt($profile->mobile_encrypted),
                'national_code' => $this->decrypt($profile->national_id_encrypted),
                'country_id' => $profile->country_id,
                'province_id' => $profile->province_id,
                'county_id' => $profile->county_id,
                'settlement_id' => $profile->settlement_id,
                'is_active' => (bool) $profile->is_active,
                'account_status' => $profile->account?->account_status,
            ],
        ]);
    }

    public function close(Request $request): JsonResponse
    {
        /** @var UserProfile $profile */
        $profile = $request->attributes->get('user_profile');
        /** @var AuthSession $session */
        $session = $request->attributes->get('auth_session');

        DB::transaction(function () use ($profile): void {
            UserAccount::query()
                ->whereKey($profile->user_id)
                ->update([
                    'account_status' => 'Closed',
                    'updated_at' => now(),
                ]);
            $profile->forceFill(['is_active' => false])->save();
            AuthSession::query()
                ->where('user_id', $profile->user_id)
                ->where('state', 'Active')
                ->update([
                    'state' => 'Revoked',
                    'terminated_at' => now(),
                    'terminal_reason' => 'Account_Closed',
                    'updated_at' => now(),
                ]);
        });

        return response()->json(['message' => 'حساب کاربری بسته شد.']);
    }

    private function decrypt(?string $value): ?string
    {
        if ($value === null || $value === '') {
            return null;
        }

        try {
            return Crypt::decryptString($value);
        } catch (\Throwable) {
            return null;
        }
    }
}
