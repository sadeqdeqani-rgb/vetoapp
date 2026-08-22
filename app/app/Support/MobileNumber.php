<?php

namespace App\Support;

use InvalidArgumentException;

final class MobileNumber
{
    public static function normalize(string $value): string
    {
        $value = strtr(trim($value), [
            '۰' => '0', '۱' => '1', '۲' => '2', '۳' => '3', '۴' => '4',
            '۵' => '5', '۶' => '6', '۷' => '7', '۸' => '8', '۹' => '9',
            '٠' => '0', '١' => '1', '٢' => '2', '٣' => '3', '٤' => '4',
            '٥' => '5', '٦' => '6', '٧' => '7', '٨' => '8', '٩' => '9',
        ]);
        $value = preg_replace('/[\s\-\(\)]/', '', $value) ?? $value;

        if (str_starts_with($value, '0098')) {
            $value = '+98'.substr($value, 4);
        } elseif (str_starts_with($value, '09')) {
            $value = '+98'.substr($value, 1);
        } elseif (str_starts_with($value, '98') && ! str_starts_with($value, '+')) {
            $value = '+'.$value;
        }

        if (! preg_match('/^\+98\d{10}$/', $value)) {
            throw new InvalidArgumentException('Invalid Iranian mobile number.');
        }

        return $value;
    }
}
