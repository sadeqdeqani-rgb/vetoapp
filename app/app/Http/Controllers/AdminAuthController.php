<?php

namespace App\Http\Controllers;

use App\Models\AdminApiToken;
use App\Models\SystemAdmin;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

class AdminAuthController extends Controller
{
    public function login(Request $request): JsonResponse
    {
        $credentials = $request->validate([
            'username' => ['required', 'string', 'max:50'],
            'password' => ['required', 'string', 'max:255'],
        ]);

        $admin = SystemAdmin::query()
            ->where('username', $credentials['username'])
            ->where('is_active', true)
            ->first();

        if ($admin === null || ! Hash::check($credentials['password'], $admin->password_hash)) {
            throw ValidationException::withMessages([
                'username' => ['نام کاربری یا رمز عبور ادمین صحیح نیست.'],
            ]);
        }

        $plainToken = Str::random(80);
        $token = AdminApiToken::create([
            'admin_id' => $admin->admin_id,
            'token_hash' => hash('sha256', $plainToken, true),
            'expires_at' => now()->addHours(12),
            'created_at' => now(),
        ]);

        return response()->json([
            'token_type' => 'Bearer',
            'access_token' => $plainToken,
            'expires_at' => $token->expires_at?->toISOString(),
            'admin' => [
                'id' => $admin->admin_id,
                'username' => $admin->username,
            ],
        ]);
    }

    public function me(Request $request): JsonResponse
    {
        $admin = $request->attributes->get('system_admin');

        return response()->json([
            'id' => $admin->admin_id,
            'username' => $admin->username,
            'is_active' => (bool) $admin->is_active,
        ]);
    }

    public function logout(Request $request): JsonResponse
    {
        $token = $request->attributes->get('admin_api_token');
        $token?->forceFill(['revoked_at' => now()])->saveQuietly();

        return response()->json(['message' => 'نشست ادمین خاتمه یافت.']);
    }

    public function create(Request $request): JsonResponse
    {
        $data = $request->validate([
            'username' => ['required', 'string', 'min:3', 'max:50', 'alpha_dash', 'unique:system_admins,username'],
            'password' => ['required', 'string', 'min:12', 'max:255', 'confirmed'],
        ]);

        $admin = DB::transaction(function () use ($data): SystemAdmin {
            return SystemAdmin::create([
                'admin_uuid' => Str::uuid()->getBytes(),
                'username' => $data['username'],
                'password_hash' => Hash::make($data['password']),
                'public_key_pem' => $this->generatePublicKey(),
                'is_active' => true,
            ]);
        });

        return response()->json([
            'id' => $admin->admin_id,
            'username' => $admin->username,
        ], 201);
    }

    private function generatePublicKey(): string
    {
        $keyPair = sodium_crypto_sign_keypair();
        $publicKey = sodium_crypto_sign_publickey($keyPair);

        return "-----BEGIN VETOAPP ADMIN PUBLIC KEY-----\n"
            . base64_encode($publicKey)
            . "\n-----END VETOAPP ADMIN PUBLIC KEY-----";
    }
}
