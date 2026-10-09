<?php

namespace App\Services;

class ElectionCandidateNormalizer
{
    public const VERSION = 1;

    public function normalizeName(string $value): string
    {
        $value = trim($value);
        if (class_exists(\Normalizer::class)) $value = \Normalizer::normalize($value, \Normalizer::FORM_KC) ?: $value;
        $value = strtr($value, [
            'ي' => 'ی', 'ى' => 'ی', 'ك' => 'ک', 'ـ' => '',
            "\u{200C}" => ' ', "\u{200D}" => ' ', "\u{FEFF}" => ' ',
            'َ' => '', 'ُ' => '', 'ِ' => '', 'ّ' => '', 'ْ' => '', 'ً' => '', 'ٌ' => '', 'ٍ' => '',
        ]);
        $value = preg_replace('/[\p{Z}\s]+/u', ' ', $value) ?? $value;
        $value = preg_replace('/\s+/u', ' ', $value) ?? $value;
        return function_exists('mb_strtolower') ? mb_strtolower(trim($value), 'UTF-8') : trim($value);
    }

    /** @return array{given:string,family:string,father:string,hash:string,label:string} */
    public function normalize(string $given, string $family, string $father): array
    {
        $names = [
            'given' => $this->normalizeName($given),
            'family' => $this->normalizeName($family),
            'father' => $this->normalizeName($father),
        ];
        $canonical = json_encode(['v' => self::VERSION] + $names, JSON_THROW_ON_ERROR | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
        return $names + ['hash' => hash('sha256', $canonical, true), 'label' => implode(' ', [$names['given'], $names['family'], 'فرزند', $names['father']])];
    }

    public function similarity(array $left, array $right): float
    {
        $scores = [];
        foreach (['given', 'family', 'father'] as $part) $scores[] = $this->textSimilarity((string) $left[$part], (string) $right[$part]);
        // Surname and father's name carry more identity information than a common given name.
        return ($scores[0] * 0.25) + ($scores[1] * 0.45) + ($scores[2] * 0.30);
    }

    private function textSimilarity(string $a, string $b): float
    {
        if ($a === $b) return 1.0;
        if ($a === '' || $b === '') return 0.0;
        $left = preg_split('//u', $a, -1, PREG_SPLIT_NO_EMPTY) ?: [];
        $right = preg_split('//u', $b, -1, PREG_SPLIT_NO_EMPTY) ?: [];
        $previous = range(0, count($right));
        foreach ($left as $i => $leftCharacter) {
            $current = [$i + 1];
            foreach ($right as $j => $rightCharacter) {
                $current[] = min(
                    $current[$j] + 1,
                    $previous[$j + 1] + 1,
                    $previous[$j] + ($leftCharacter === $rightCharacter ? 0 : 1),
                );
            }
            $previous = $current;
        }
        return 1.0 - ($previous[count($right)] / max(count($left), count($right), 1));
    }
}
