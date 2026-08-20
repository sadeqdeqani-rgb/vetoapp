<?php

namespace App\Support;

final class IranianNationalCodeValidator
{
    public const TEST_NATIONAL_CODE = '1111111111';

    public static function normalize(string $value): string
    {
        return strtr(trim($value), [
            '۰' => '0', '۱' => '1', '۲' => '2', '۳' => '3', '۴' => '4',
            '۵' => '5', '۶' => '6', '۷' => '7', '۸' => '8', '۹' => '9',
            '٠' => '0', '١' => '1', '٢' => '2', '٣' => '3', '٤' => '4',
            '٥' => '5', '٦' => '6', '٧' => '7', '٨' => '8', '٩' => '9',
        ]);
    }

    public static function isValid(
        string $value,
        bool $allowTestCode = false,
    ): bool {
        $code = self::normalize($value);

        if ($allowTestCode && $code === self::TEST_NATIONAL_CODE) return true;
        if (!preg_match('/^\d{10}$/', $code)) return false;
        if (preg_match('/^(\d)\1{9}$/', $code)) return false;

        $sum = 0;
        for ($index = 0; $index < 9; $index++) {
            $sum += (int) $code[$index] * (10 - $index);
        }

        $remainder = $sum % 11;
        $checkDigit = (int) $code[9];
        $expectedDigit = $remainder < 2 ? $remainder : 11 - $remainder;

        return $checkDigit === $expectedDigit;
    }
}
