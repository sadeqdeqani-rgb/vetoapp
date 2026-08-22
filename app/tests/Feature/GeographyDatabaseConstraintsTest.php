<?php

namespace Tests\Feature;

use App\Models\County;
use App\Models\Country;
use App\Models\Province;
use App\Models\Settlement;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Database\QueryException;
use Tests\TestCase;

class GeographyDatabaseConstraintsTest extends TestCase
{
    use DatabaseTransactions;

    protected function setUp(): void
    {
        parent::setUp();

        if (
            DB::getDriverName() !== 'mysql'
            || ! Schema::hasTable('countries')
            || DB::table('countries')->count() === 0
        ) {
            $this->markTestSkipped('These tests require the seeded MySQL geography database.');
        }
    }

    public function test_foreign_keys_reject_invalid_geography_parents(): void
    {
        $this->expectException(QueryException::class);

        DB::table('provinces')->insert([
            'country_id' => 0,
            'province_code' => 65535,
            'name_fa' => 'رکورد نامعتبر',
            'is_active' => true,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    public function test_geography_codes_are_unique_at_database_level(): void
    {
        $country = Country::query()->firstOrFail();
        $province = Province::query()->firstOrFail();
        $county = County::query()->firstOrFail();
        $settlement = Settlement::query()->firstOrFail();

        try {
            DB::table('countries')->insert([
                'country_code' => $country->country_code,
                'name_fa' => 'کشور تکراری',
                'is_active' => true,
                'created_at' => now(),
                'updated_at' => now(),
            ]);
            $this->fail('Duplicate country_code was accepted.');
        } catch (QueryException) {
            $this->addToAssertionCount(1);
        }

        try {
            DB::table('provinces')->insert([
                'country_id' => $province->country_id,
                'province_code' => $province->province_code,
                'name_fa' => 'استان تکراری',
                'is_active' => true,
                'created_at' => now(),
                'updated_at' => now(),
            ]);
            $this->fail('Duplicate province_code was accepted.');
        } catch (QueryException) {
            $this->addToAssertionCount(1);
        }

        try {
            DB::table('counties')->insert([
                'province_id' => $county->province_id,
                'county_code' => $county->county_code,
                'name_fa' => 'شهرستان تکراری',
                'is_active' => true,
                'created_at' => now(),
                'updated_at' => now(),
            ]);
            $this->fail('Duplicate county_code was accepted.');
        } catch (QueryException) {
            $this->addToAssertionCount(1);
        }

        try {
            DB::table('settlements')->insert([
                'county_id' => $settlement->county_id,
                'settlement_code' => $settlement->settlement_code,
                'name_fa' => 'Settlement تکراری',
                'is_active' => true,
                'created_at' => now(),
                'updated_at' => now(),
            ]);
            $this->fail('Duplicate settlement_code was accepted.');
        } catch (QueryException) {
            $this->addToAssertionCount(1);
        }
    }

    public function test_active_scopes_exclude_inactive_nodes_at_each_level(): void
    {
        $country = Country::query()->firstOrFail();
        $province = Province::query()->where('country_id', $country->country_id)->firstOrFail();
        $county = County::query()->where('province_id', $province->province_id)->firstOrFail();
        $settlement = Settlement::query()->where('county_id', $county->county_id)->firstOrFail();

        DB::table('countries')->where('country_id', $country->country_id)->update(['is_active' => false]);
        DB::table('provinces')->where('province_id', $province->province_id)->update(['is_active' => false]);
        DB::table('counties')->where('county_id', $county->county_id)->update(['is_active' => false]);
        DB::table('settlements')->where('settlement_id', $settlement->settlement_id)->update(['is_active' => false]);

        $this->assertFalse(Country::active()->whereKey($country->country_id)->exists());
        $this->assertFalse(Province::active()->whereKey($province->province_id)->exists());
        $this->assertFalse(County::active()->whereKey($county->county_id)->exists());
        $this->assertFalse(Settlement::active()->whereKey($settlement->settlement_id)->exists());
    }

    public function test_hierarchy_scope_requires_the_same_country_province_and_county_branch(): void
    {
        $country = Country::active()->with('activeProvinces.activeCounties.activeSettlements')->firstOrFail();
        $province = $country->activeProvinces->firstOrFail();
        $county = $province->activeCounties->firstOrFail();
        $settlement = $county->activeSettlements->firstOrFail();

        $this->assertTrue(
            Settlement::active()
                ->withinHierarchy($country->country_id, $province->province_id, $county->county_id)
                ->whereKey($settlement->settlement_id)
                ->exists()
        );

        $otherProvince = $country->activeProvinces
            ->first(fn (Province $item): bool => $item->province_id !== $province->province_id);

        if ($otherProvince === null) {
            $this->markTestSkipped('The seeded country has no second province.');
        }

        $this->assertFalse(
            Settlement::active()
                ->withinHierarchy($country->country_id, $otherProvince->province_id, $county->county_id)
                ->whereKey($settlement->settlement_id)
                ->exists()
        );
    }
}
