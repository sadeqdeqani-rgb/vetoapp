<?php

namespace App\Services;

class ReferendumSubjectNormalizer
{
    public const VERSION = 1;

    public function normalize(string $value): string
    {
        $value = trim($value);
        if (class_exists(\Normalizer::class)) {
            $value = \Normalizer::normalize($value, \Normalizer::FORM_KC) ?: $value;
        }

        $value = strtr($value, [
            'ي' => 'ی', 'ى' => 'ی', 'ك' => 'ک', 'ـ' => '',
            "\u{200C}" => ' ', "\u{200D}" => ' ', "\u{FEFF}" => ' ',
            'َ' => '', 'ُ' => '', 'ِ' => '', 'ّ' => '', 'ْ' => '', 'ً' => '', 'ٌ' => '', 'ٍ' => '',
        ]);
        $value = preg_replace('/[\p{Z}\s]+/u', ' ', $value) ?? $value;
        $value = preg_replace('/\s*([،؛:!?؟,.])\s*/u', '$1 ', $value) ?? $value;
        $value = preg_replace('/\s+/u', ' ', $value) ?? $value;
        if (function_exists('mb_strtolower')) $value = mb_strtolower($value, 'UTF-8');

        return trim($value);
    }

    public function hash(string $normalized): string
    {
        return hash('sha256', $normalized, true);
    }

    public function containsDirectionalTerm(string $normalized, iterable $terms): bool
    {
        foreach ($terms as $term) {
            $needle = trim((string) $term);
            if ($needle === '') continue;
            $pattern = '/(?<![\p{L}\p{N}])'.preg_quote($needle, '/').'(?![\p{L}\p{N}])/u';
            if (preg_match($pattern, $normalized) === 1) return true;
        }

        return false;
    }

    public function similarity(string $left, string $right): float
    {
        if ($left === $right) return 1.0;
        $a = $this->bigrams($left);
        $b = $this->bigrams($right);
        if ($a === [] || $b === []) return 0.0;
        $intersection = 0;
        foreach ($a as $gram => $count) {
            $intersection += min($count, $b[$gram] ?? 0);
        }

        return (2 * $intersection) / (array_sum($a) + array_sum($b));
    }

    private function bigrams(string $value): array
    {
        $characters = preg_split('//u', $value, -1, PREG_SPLIT_NO_EMPTY) ?: [];
        $counts = [];
        for ($index = 0; $index < count($characters) - 1; $index++) {
            $gram = $characters[$index].$characters[$index + 1];
            $counts[$gram] = ($counts[$gram] ?? 0) + 1;
        }

        return $counts;
    }
}
