<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use RuntimeException;

class IranGeographySeeder extends Seeder
{
    private const DEFAULT_COUNTRY_CODE = 364;

    public function run(): void
    {
        $citiesFile = (string) env('GEOGRAPHY_CITIES_FILE', database_path('seed_data/فهرست-شهرهای-ایران.md'));
        $villagesFile = (string) env('GEOGRAPHY_VILLAGES_FILE', database_path('seed_data/فهرست-روستاهای-ایران.md'));

        $cityRows = $this->parseMarkdown($citiesFile);
        $villageRows = $this->parseMarkdown($villagesFile);
        $zeroPopulationKeys = $this->zeroPopulationKeys();

        if ($cityRows === [] || $villageRows === []) {
            throw new RuntimeException('Geography source files must contain at least one settlement.');
        }

        DB::transaction(function () use ($cityRows, $villageRows, $zeroPopulationKeys): void {
            if (filter_var(env('GEOGRAPHY_RESEED_RESET', false), FILTER_VALIDATE_BOOL)) {
                $this->resetGeography();
            }
            $settlementActiveStates = DB::table('settlements')
                ->pluck('is_active', 'settlement_code')
                ->all();

            DB::table('countries')->updateOrInsert(
                ['country_code' => self::DEFAULT_COUNTRY_CODE],
                ['name_fa' => 'ایران', 'is_active' => true, 'updated_at' => now(), 'created_at' => now()],
            );
            $countryId = (int) DB::table('countries')
                ->where('country_code', self::DEFAULT_COUNTRY_CODE)
                ->value('country_id');

            $provinceIds = [];
            $provinceCodes = [];
            $provinceOrder = 0;
            foreach ($this->orderedUnique(array_merge($cityRows, $villageRows), 'province') as $provinceRow) {
                $province = $provinceRow['province'];
                $provinceOrder++;
                $provinceCodes[$province] = $provinceOrder;
                DB::table('provinces')->updateOrInsert(
                    ['province_code' => $provinceOrder],
                    ['country_id' => $countryId, 'name_fa' => $province, 'is_active' => true, 'updated_at' => now(), 'created_at' => now()],
                );
                $provinceIds[$province] = (int) DB::table('provinces')
                    ->where('province_code', $provinceOrder)
                    ->value('province_id');
            }

            $allRows = array_merge($cityRows, $villageRows);
            $countyIds = [];
            $countyLocalCodes = [];
            $countyLocalOrders = [];
            foreach ($this->orderedUnique($allRows, 'county', ['province']) as $row) {
                $key = $row['province']."\0".$row['county'];
                $countyLocalOrders[$row['province']] = ($countyLocalOrders[$row['province']] ?? 0) + 1;
                $countyLocalCodes[$key] = $countyLocalOrders[$row['province']];
                $countyCode = ($provinceCodes[$row['province']] * 100) + $countyLocalCodes[$key];
                DB::table('counties')->updateOrInsert(
                    ['county_code' => $countyCode],
                    ['province_id' => $provinceIds[$row['province']], 'name_fa' => $row['county'], 'is_active' => true, 'updated_at' => now(), 'created_at' => now()],
                );
                $countyIds[$key] = (int) DB::table('counties')
                    ->where('county_code', $countyCode)
                    ->value('county_id');
            }

            $settlementLocalOrders = [];
            foreach ([[$cityRows, false], [$villageRows, true]] as [$rows, $isVillageSource]) {
                foreach ($rows as $row) {
                    $key = $row['province']."\0".$row['county'];
                    $settlementLocalOrders[$key] = ($settlementLocalOrders[$key] ?? 0) + 1;
                    $settlementCode = ($provinceCodes[$row['province']] * 1_000_000)
                        + ($countyLocalCodes[$key] * 10_000)
                        + $settlementLocalOrders[$key];
                    $zeroPopulationKey = implode("\0", array_map(
                        fn (string $value): string => $this->normalizeGeographyName($value),
                        [$row['province'], $row['settlement']],
                    ));
                    DB::table('settlements')->updateOrInsert(
                        ['settlement_code' => $settlementCode],
                        [
                        'county_id' => $countyIds[$key],
                        'name_fa' => $row['settlement'],
                        'is_active' => $this->seededSettlementActiveState(
                            $settlementCode,
                            $isVillageSource && isset($zeroPopulationKeys[$zeroPopulationKey]),
                            $settlementActiveStates,
                        ),
                        'created_at' => now(),
                        'updated_at' => now(),
                        ]
                    );
                }
            }
        });
    }

    private function resetGeography(): void
    {
        foreach ([
            'settlement_active_user_counters',
            'user_profiles',
            'registration_drafts',
            'user_geo_change_logs',
        ] as $table) {
            if (DB::table($table)->exists()) {
                throw new RuntimeException("Cannot reset geography while {$table} contains records.");
            }
        }

        DB::table('settlements')->delete();
        DB::table('counties')->delete();
        DB::table('provinces')->delete();
        DB::table('countries')->where('country_code', self::DEFAULT_COUNTRY_CODE)->delete();
    }

    private function parseMarkdown(string $path): array
    {
        if (! is_file($path)) {
            throw new RuntimeException("Geography source file not found: {$path}");
        }

        $province = null;
        $county = null;
        $rows = [];

        foreach (file($path, FILE_IGNORE_NEW_LINES) ?: [] as $line) {
            $line = trim($line);
            if (str_starts_with($line, '## ')) {
                $province = trim(substr($line, 3));
                $county = null;
            } elseif (str_starts_with($line, '### ')) {
                $county = trim(substr($line, 4));
            } elseif (str_starts_with($line, '- ') && ! str_starts_with($line, '- تعداد')) {
                if ($province === null || $county === null) {
                    continue;
                }
                $rows[] = ['province' => $province, 'county' => $county, 'settlement' => trim(substr($line, 2))];
            }
        }

        return $rows;
    }

    private function orderedUnique(array $rows, string $field, array $parents = []): array
    {
        $seen = [];
        $result = [];
        foreach ($rows as $row) {
            $key = implode("\0", array_map(fn (string $parent): string => $row[$parent], $parents))."\0".$row[$field];
            if (! isset($seen[$key])) {
                $seen[$key] = true;
                $result[] = $row;
            }
        }
        return $result;
    }

    private function zeroPopulationKeys(): array
    {
        $path = database_path('seed_data/zero_population_province_targets_1395.tsv');
        if (! is_file($path)) {
            throw new RuntimeException("Zero-population settlement source file not found: {$path}");
        }

        $keys = [];
        foreach (file($path, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) ?: [] as $index => $line) {
            if ($index === 0) {
                continue;
            }
            $columns = str_getcsv($line, "\t");
            if (count($columns) < 2) {
                continue;
            }
            $key = implode("\0", array_map(
                fn (string $value): string => $this->normalizeGeographyName($value),
                array_slice($columns, 0, 2),
            ));
            $keys[$key] = true;
        }

        return $keys;
    }

    private function normalizeGeographyName(string $value): string
    {
        $value = strtr(trim($value), [
            'ي' => 'ی', 'ى' => 'ی', 'ك' => 'ک',
            "\u{200c}" => ' ', "\u{200f}" => '',
        ]);

        return preg_replace('/\s+/u', ' ', $value) ?? $value;
    }

    private function seededSettlementActiveState(
        int $settlementCode,
        bool $zeroPopulationVillage,
        array $existingStates,
    ): bool {
        if ($zeroPopulationVillage) {
            return false;
        }

        if (array_key_exists($settlementCode, $existingStates)) {
            return (bool) $existingStates[$settlementCode];
        }

        return true;
    }
}
