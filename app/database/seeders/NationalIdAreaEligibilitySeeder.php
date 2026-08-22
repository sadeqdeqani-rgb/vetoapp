<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class NationalIdAreaEligibilitySeeder extends Seeder
{
    public function run(): void
    {
        $now = now();
        $rows = [];

        foreach (require database_path('seed_data/national_id_prefixes.php') as $prefix) {
            $rows[] = [
                'national_id_prefix_3' => (int) $prefix,
                'first_range_from' => 0,
                'first_range_to' => 999,
                'second_range_from' => 0,
                'second_range_to' => 999,
                'created_at' => $now,
                'updated_at' => $now,
            ];
        }

        foreach (array_chunk($rows, 250) as $chunk) {
            DB::table('national_id_area_eligibilities')->upsert(
                $chunk,
                ['national_id_prefix_3'],
                [
                    'first_range_from',
                    'first_range_to',
                    'second_range_from',
                    'second_range_to',
                    'updated_at',
                ],
            );
        }
    }
}
