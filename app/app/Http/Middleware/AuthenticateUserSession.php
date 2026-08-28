<?php

namespace App\Http\Middleware;

use App\Models\AuthSession;
use Closure;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Symfony\Component\HttpFoundation\Response;

class AuthenticateUserSession
{
    public function handle(Request $request, Closure $next): Response
    {
        $header = (string) $request->header('Authorization');
        $token = str_starts_with($header, 'Bearer ')
            ? trim(substr($header, 7))
            : '';

        if (! Str::isUuid($token)) {
            return new JsonResponse(['message' => 'نشست کاربر معتبر نیست.'], 401);
        }

        $session = DB::transaction(function () use ($token): ?AuthSession {
            $now = now();
            $session = AuthSession::query()
                ->where('session_uuid', hex2bin(str_replace('-', '', $token)))
                ->lockForUpdate()
                ->first();

            if ($session === null || $session->state !== 'Active') {
                return $session;
            }

            $terminationReason = null;
            $terminatedAt = null;
            if ($now->greaterThanOrEqualTo($session->expires_at)) {
                $terminationReason = 'expired';
                $terminatedAt = $session->expires_at;
            } elseif ($now->greaterThanOrEqualTo($session->last_activity_at->copy()->addMinutes(15))) {
                $terminationReason = 'inactivity_timeout';
                $terminatedAt = $session->last_activity_at->copy()->addMinutes(15);
            }

            if ($terminationReason !== null) {
                $session->forceFill([
                    'state' => 'Expired',
                    'terminal_reason' => $terminationReason,
                    'terminated_at' => $terminatedAt,
                    'updated_at' => $now,
                ])->saveQuietly();
            }

            return $session->fresh();
        });

        $session?->loadMissing('profile.account');

        if ($session === null || $session->profile === null || ! $session->profile->is_active) {
            return new JsonResponse(['message' => 'نشست کاربر منقضی یا غیرفعال است.'], 401);
        }

        if ($session->state !== 'Active') {
            return new JsonResponse(['message' => 'نشست کاربر منقضی یا غیرفعال است.'], 401);
        }

        $session->forceFill(['last_activity_at' => now()])->saveQuietly();
        $request->attributes->set('auth_session', $session);
        $request->attributes->set('user_profile', $session->profile);

        return $next($request);
    }
}
