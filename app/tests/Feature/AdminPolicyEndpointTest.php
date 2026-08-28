<?php

namespace Tests\Feature;

use App\Models\AdminApiToken;
use App\Models\SystemAdmin;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Tests\TestCase;

class AdminPolicyEndpointTest extends TestCase
{
    use RefreshDatabase;

    private string $token;

    protected function setUp(): void
    {
        parent::setUp();

        $admin = SystemAdmin::create([
            'admin_uuid' => Str::uuid()->getBytes(),
            'username' => 'policy-admin',
            'password_hash' => Hash::make('password'),
            'public_key_pem' => 'test-key',
            'is_active' => true,
        ]);
        $this->token = Str::random(80);
        AdminApiToken::create([
            'admin_id' => $admin->getKey(),
            'token_hash' => hash('sha256', $this->token, true),
            'expires_at' => now()->addHour(),
            'created_at' => now(),
        ]);
    }

    public function test_geo_policy_crud_is_authenticated_validated_and_audited(): void
    {
        $payload = [
            'policy_code' => 'geo_test',
            'policy_name' => 'Geo Test',
            'description' => 'test',
            'policy_stage' => 1,
            'cooldown_days' => 30,
            'is_active' => true,
            'effective_from' => '2026-08-24 00:00:00',
        ];

        $this->getJson('/api/admin/geo-cooldown-policies')->assertUnauthorized();
        $create = $this->authRequest()->postJson('/api/admin/geo-cooldown-policies', $payload);
        $create->assertCreated()->assertJsonPath('data.policy_code', 'geo_test');
        $id = $create->json('data.policy_id');

        $this->authRequest()->patchJson("/api/admin/geo-cooldown-policies/{$id}", [
            'policy_code' => 'geo_test_updated',
            ...$payload,
            'policy_name' => 'Geo Updated',
        ])->assertOk()->assertJsonPath('data.policy_name', 'Geo Updated');

        $this->authRequest()->deleteJson("/api/admin/geo-cooldown-policies/{$id}")->assertOk();
        $this->assertDatabaseMissing('geo_cooldown_policies', ['policy_id' => $id]);
        $this->assertSame(3, DB::table('admin_activity_logs')->where('target_table', 'geo_cooldown_policies')->count());
    }

    public function test_policy_validation_matches_schema_and_unique_stage_constraints(): void
    {
        $payload = [
            'policy_code' => 'geo_duplicate',
            'policy_name' => 'Geo',
            'policy_stage' => 1,
            'cooldown_days' => 0,
            'effective_from' => '2026-08-24 00:00:00',
        ];

        $this->authRequest()->postJson('/api/admin/geo-cooldown-policies', $payload)
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['cooldown_days']);

        $valid = [...$payload, 'cooldown_days' => 1];
        $this->authRequest()->postJson('/api/admin/geo-cooldown-policies', $valid)->assertCreated();
        $this->authRequest()->postJson('/api/admin/geo-cooldown-policies', $valid)
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['policy_code']);
    }

    public function test_closure_policy_can_be_listed_created_updated_and_deleted_with_audit(): void
    {
        $payload = [
            'policy_family_code' => 'account_closure',
            'policy_code' => 'closure_test',
            'policy_name' => 'Closure Test',
            'penalty_stage' => 1,
            'penalty_hours' => 24,
            'trigger_scope' => 'account_closure',
            'is_active' => true,
            'effective_from' => '2026-08-24 00:00:00',
        ];

        $create = $this->authRequest()->postJson('/api/admin/account-closure-penalty-policies', $payload);
        $create->assertCreated();
        $id = $create->json('data.policy_id');
        $this->authRequest()->getJson('/api/admin/account-closure-penalty-policies')
            ->assertOk()
            ->assertJsonPath('data.data.0.policy_code', 'closure_test');
        $this->authRequest()->patchJson("/api/admin/account-closure-penalty-policies/{$id}", ['penalty_hours' => 48])
            ->assertOk()->assertJsonPath('data.penalty_hours', 48);
        $this->authRequest()->deleteJson("/api/admin/account-closure-penalty-policies/{$id}")->assertOk();
        $this->assertSame(3, DB::table('admin_activity_logs')->where('target_table', 'account_closure_penalty_policies')->count());
    }

    private function authRequest(): static
    {
        return $this->withHeader('Authorization', "Bearer {$this->token}");
    }
}
