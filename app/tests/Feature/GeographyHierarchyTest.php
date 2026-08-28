<?php

namespace Tests\Feature;

use App\Models\Country;
use App\Models\Settlement;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Foundation\Testing\WithoutMiddleware;
use Tests\TestCase;

class GeographyHierarchyTest extends TestCase
{
    use WithoutMiddleware;
    use RefreshDatabase;
    use CreatesTestGeography;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seedTestGeography();
    }

    public function test_active_scope_and_parent_child_relations_follow_the_drm_hierarchy(): void
    {
        $country = Country::active()->with('activeProvinces.activeCounties.activeSettlements')->firstOrFail();
        $province = $country->activeProvinces->firstOrFail();
        $county = $province->activeCounties->firstOrFail();
        $settlement = $county->activeSettlements->firstOrFail();

        $this->assertTrue($country->is_active);
        $this->assertTrue($province->is_active);
        $this->assertTrue($county->is_active);
        $this->assertTrue($settlement->is_active);

        $this->assertSame($country->country_id, $province->country_id);
        $this->assertSame($province->province_id, $county->province_id);
        $this->assertSame($county->county_id, $settlement->county_id);
        $this->assertSame($country->country_id, $province->country->country_id);
        $this->assertSame($province->province_id, $county->province->province_id);
        $this->assertSame($county->county_id, $settlement->county->county_id);
    }

    public function test_settlement_selection_rejects_a_county_from_another_branch(): void
    {
        $country = Country::active()->with('activeProvinces.activeCounties.activeSettlements')->firstOrFail();
        $province = $country->activeProvinces->firstOrFail();
        $county = $province->activeCounties->firstOrFail();
        $settlement = $county->activeSettlements->firstOrFail();
        $otherCounty = $country->activeProvinces
            ->flatMap(fn ($item) => $item->activeCounties)
            ->first(fn ($item) => $item->province_id !== $province->province_id);

        if ($otherCounty === null) {
            $this->markTestSkipped('The seeded country has no second province.');
        }

        $this->assertFalse(
            Settlement::active()
                ->withinHierarchy($country->country_id, $province->province_id, $otherCounty->county_id)
                ->whereKey($settlement->settlement_id)
                ->exists()
        );
    }

    public function test_hierarchical_settlement_code_resolves_the_settlement_directly(): void
    {
        $settlement = Settlement::active()->orderBy('settlement_code')->firstOrFail();
        $resolved = Settlement::active()
            ->where('settlement_code', $settlement->settlement_code)
            ->firstOrFail();

        $this->assertSame($settlement->settlement_id, $resolved->settlement_id);
        $this->assertGreaterThanOrEqual(1_000_000, $settlement->settlement_code);
        $this->assertLessThanOrEqual(99_999_999, $settlement->settlement_code);
    }
}
