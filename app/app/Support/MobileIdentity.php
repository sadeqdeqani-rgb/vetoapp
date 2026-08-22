<?php

namespace App\Support;

use RuntimeException;

final class MobileIdentity
{
    public static function hash(string $normalizedMobile): string
    {
        $secret = (string) env('MOBILE_HMAC_SECRET');
        if ($secret === '') {
            throw new RuntimeException('MOBILE_HMAC_SECRET is not configured.');
        }

        return hash_hmac('sha256', $normalizedMobile, $secret, true);
    }
}
