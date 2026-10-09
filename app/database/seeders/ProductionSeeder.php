<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;

class ProductionSeeder extends Seeder
{
    /**
     * Seed only idempotent reference data required by the production API.
     * Deliberately excludes the sample user from DatabaseSeeder.
     */
    public function run(): void
    {
        $this->call([
            VetoAppLookupSeeder::class,
            ProcessDomainLookupSeeder::class,
            IranGeographySeeder::class,
            HomeStateSeeder::class,
            HomeContentSeeder::class,
            NationalIdAreaEligibilitySeeder::class,
        ]);
    }
}
