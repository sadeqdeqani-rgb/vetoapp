<?php

namespace Tests\Feature;

use Illuminate\Support\Facades\DB;

trait CreatesTestGeography
{
    protected function seedTestGeography(): void
    {
        $now = now();

        DB::table('countries')->insert([
            'country_code' => 364,
            'name_fa' => 'ایران',
            'is_active' => true,
            'created_at' => $now,
            'updated_at' => $now,
        ]);
        $countryId = (int) DB::getPdo()->lastInsertId();

        foreach ([
            ['code' => 1, 'name' => 'استان آزمایشی یک'],
            ['code' => 2, 'name' => 'استان آزمایشی دو'],
        ] as $provinceData) {
            DB::table('provinces')->insert([
                'country_id' => $countryId,
                'province_code' => $provinceData['code'],
                'name_fa' => $provinceData['name'],
                'is_active' => true,
                'created_at' => $now,
                'updated_at' => $now,
            ]);
            $provinceId = (int) DB::getPdo()->lastInsertId();

            DB::table('counties')->insert([
                'province_id' => $provinceId,
                'county_code' => $provinceData['code'] * 100 + 1,
                'name_fa' => 'شهرستان آزمایشی',
                'is_active' => true,
                'created_at' => $now,
                'updated_at' => $now,
            ]);
            $countyId = (int) DB::getPdo()->lastInsertId();

            DB::table('settlements')->insert([
                'county_id' => $countyId,
                'settlement_code' => $provinceData['code'] * 1_000_000 + 10_001,
                'name_fa' => 'سکونتگاه آزمایشی',
                'is_active' => true,
                'created_at' => $now,
                'updated_at' => $now,
            ]);
        }
    }
}
