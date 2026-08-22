<?php

namespace App\Support;

use RuntimeException;

final class OtpCodeHasher
{
    public static function hash(string $code, string $purpose, string $mobileHash, string $nonce): string
    {
        $secret = (string) env('OTP_SERVER_SECRET');
        if ($secret === '') {
            throw new RuntimeException('OTP_SERVER_SECRET is not configured.');
        }

        return hash_hmac('sha256', $code.$purpose.$mobileHash.$nonce, $secret, true);
    }
}
