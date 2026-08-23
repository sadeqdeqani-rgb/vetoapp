<?php

namespace App\Http\Middleware;

use App\Models\AdminApiToken;
use Closure;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class AuthenticateSystemAdmin
{
    public function handle(Request $request, Closure $next): Response
    {
        $plainToken = $request->bearerToken();

        if (! is_string($plainToken) || $plainToken === '') {
            return $this->unauthorized();
        }

        $token = AdminApiToken::query()
            ->with('admin')
            ->where('token_hash', hash('sha256', $plainToken, true))
            ->whereNull('revoked_at')
            ->where('expires_at', '>', now())
            ->first();

        if ($token === null || $token->admin === null || ! $token->admin->is_active) {
            return $this->unauthorized();
        }

        $token->forceFill(['last_used_at' => now()])->saveQuietly();
        $request->attributes->set('system_admin', $token->admin);
        $request->attributes->set('admin_api_token', $token);

        return $next($request);
    }

    private function unauthorized(): JsonResponse
    {
        return response()->json([
            'message' => 'احراز هویت ادمین الزامی است.',
        ], 401);
    }
}
