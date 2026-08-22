<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class NationalIdAreaEligibilitySeederTest extends TestCase
{
    use RefreshDatabase;

    public function test_prefixes_are_seeded_as_independent_sorted_rows_with_full_ranges(): void
    {
        $this->seed(\Database\Seeders\NationalIdAreaEligibilitySeeder::class);

        $this->assertSame(597, DB::table('national_id_area_eligibilities')->count());

        $this->assertDatabaseHas('national_id_area_eligibilities', [
            'national_id_prefix_3' => 228,
            'first_range_from' => 0,
            'first_range_to' => 999,
            'second_range_from' => 0,
            'second_range_to' => 999,
        ]);
        $this->assertDatabaseHas('national_id_area_eligibilities', [
            'national_id_prefix_3' => 229,
        ]);
        $this->assertDatabaseHas('national_id_area_eligibilities', [
            'national_id_prefix_3' => 230,
        ]);

        $prefixes = DB::table('national_id_area_eligibilities')
            ->orderBy('national_id_prefix_3')
            ->pluck('national_id_prefix_3')
            ->all();

        $this->assertSame($prefixes, array_values(array_unique($prefixes)));
        $this->assertSame($prefixes, collect($prefixes)->sort()->values()->all());
    }

    public function test_seeder_is_idempotent(): void
    {
        $this->seed(\Database\Seeders\NationalIdAreaEligibilitySeeder::class);
        $this->seed(\Database\Seeders\NationalIdAreaEligibilitySeeder::class);

        $this->assertSame(597, DB::table('national_id_area_eligibilities')->count());
    }
}
