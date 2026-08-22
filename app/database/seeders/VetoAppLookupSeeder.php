<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class VetoAppLookupSeeder extends Seeder
{
    public function run(): void
    {
        DB::table('geographic_level_lookups')->upsert([
            ['geographic_level_code' => 1, 'geographic_level_title' => 'Country', 'hierarchy_rank' => 1, 'lock_order' => 4, 'is_active' => 1],
            ['geographic_level_code' => 2, 'geographic_level_title' => 'Province', 'hierarchy_rank' => 2, 'lock_order' => 3, 'is_active' => 1],
            ['geographic_level_code' => 3, 'geographic_level_title' => 'County', 'hierarchy_rank' => 3, 'lock_order' => 2, 'is_active' => 1],
            ['geographic_level_code' => 4, 'geographic_level_title' => 'Settlement', 'hierarchy_rank' => 4, 'lock_order' => 1, 'is_active' => 1],
        ], ['geographic_level_code'], ['geographic_level_title', 'hierarchy_rank', 'lock_order', 'is_active']);

        $this->upsertLookup('otp_state_lookups', [
            ['state_code' => 'Issued', 'state_name' => 'Issued', 'display_order' => 1],
            ['state_code' => 'Verified', 'state_name' => 'Verified', 'display_order' => 2],
            ['state_code' => 'Expired', 'state_name' => 'Expired', 'display_order' => 3],
            ['state_code' => 'Failed', 'state_name' => 'Failed', 'display_order' => 4],
        ], 'state_code');

        $this->upsertLookup('otp_purpose_lookups', [
            ['purpose_code' => 'registration', 'purpose_name' => 'Registration', 'display_order' => 1],
            ['purpose_code' => 'password_reset', 'purpose_name' => 'Password Reset', 'display_order' => 2],
        ], 'purpose_code');

        $this->upsertLookup('otp_throttle_window_state_lookups', [
            ['state_code' => 'Open', 'state_name' => 'Open', 'display_order' => 1],
            ['state_code' => 'Throttled', 'state_name' => 'Throttled', 'display_order' => 2],
            ['state_code' => 'Blocked', 'state_name' => 'Blocked', 'display_order' => 3],
            ['state_code' => 'Expired', 'state_name' => 'Expired', 'display_order' => 4],
        ], 'state_code');

        $this->upsertLookup('integration_inbox_status_lookups', [
            ['status_code' => 'Pending', 'status_name' => 'Pending', 'display_order' => 1],
            ['status_code' => 'Processed', 'status_name' => 'Processed', 'display_order' => 2],
            ['status_code' => 'Failed', 'status_name' => 'Failed', 'display_order' => 3],
            ['status_code' => 'Ignored', 'status_name' => 'Ignored', 'display_order' => 4],
        ], 'status_code');

        $this->upsertLookup('registration_draft_state_lookups', [
            ['state_code' => 'Initiated', 'state_name' => 'Initiated', 'is_default' => 1, 'display_order' => 1],
            ['state_code' => 'Completed', 'state_name' => 'Completed', 'is_default' => 0, 'display_order' => 2],
            ['state_code' => 'Expired', 'state_name' => 'Expired', 'is_default' => 0, 'display_order' => 3],
        ], 'state_code');

        $this->upsertLookup('registration_draft_step_lookups', [
            ['step_code' => 'Mobile_Verification', 'step_name' => 'Mobile Verification', 'is_default' => 1, 'display_order' => 1],
            ['step_code' => 'National_ID_Verification', 'step_name' => 'National ID Verification', 'is_default' => 0, 'display_order' => 2],
            ['step_code' => 'Geographic_Selection', 'step_name' => 'Geographic Selection', 'is_default' => 0, 'display_order' => 3],
            ['step_code' => 'Password_Selection', 'step_name' => 'Password Selection', 'is_default' => 0, 'display_order' => 4],
            ['step_code' => 'Biometric_Setup', 'step_name' => 'Biometric Setup', 'is_default' => 0, 'display_order' => 5],
            ['step_code' => 'Final_Review', 'step_name' => 'Final Review', 'is_default' => 0, 'display_order' => 6],
        ], 'step_code');

        $this->upsertLookup('auth_session_state_lookups', [
            ['state_code' => 'Active', 'state_name' => 'Active', 'display_order' => 1],
            ['state_code' => 'Expired', 'state_name' => 'Expired', 'display_order' => 2],
            ['state_code' => 'Revoked', 'state_name' => 'Revoked', 'display_order' => 3],
            ['state_code' => 'LoggedOut', 'state_name' => 'Logged Out', 'display_order' => 4],
        ], 'state_code');

        DB::table('system_state_lookups')->upsert([
            ['state_code' => 1, 'state_name' => 'Activation phase', 'description' => 'Waiting for initial threshold'],
            ['state_code' => 2, 'state_name' => 'Referendum ready state', 'description' => null],
            ['state_code' => 3, 'state_name' => 'First Presidential Election', 'description' => null],
            ['state_code' => 4, 'state_name' => 'First Provincial/State Elections', 'description' => null],
            ['state_code' => 5, 'state_name' => 'First County/Governorship Elections', 'description' => null],
            ['state_code' => 6, 'state_name' => 'First Municipal Elections', 'description' => null],
            ['state_code' => 7, 'state_name' => 'System completely deployed/finalized', 'description' => null],
        ], ['state_code'], ['state_name', 'description']);

        DB::table('security_policies')->updateOrInsert(
            ['is_active' => true],
            [
                'max_failed_attempts' => 5,
                'base_lockout_seconds' => 900,
                'progressive_factor' => 2.0,
                'max_lockout_seconds' => 86400,
            ]
        );

        DB::table('geo_cooldown_policies')->upsert([
            ['policy_code' => 'geo_reassignment_default', 'policy_name' => 'Geo Reassignment Default', 'policy_stage' => 1, 'cooldown_days' => 30, 'is_active' => 1, 'effective_from' => now()],
            ['policy_code' => 'geo_reassignment_default', 'policy_name' => 'Geo Reassignment Default', 'policy_stage' => 2, 'cooldown_days' => 60, 'is_active' => 1, 'effective_from' => now()],
            ['policy_code' => 'geo_reassignment_default', 'policy_name' => 'Geo Reassignment Default', 'policy_stage' => 3, 'cooldown_days' => 120, 'is_active' => 1, 'effective_from' => now()],
            ['policy_code' => 'geo_reassignment_default', 'policy_name' => 'Geo Reassignment Default', 'policy_stage' => 4, 'cooldown_days' => 180, 'is_active' => 1, 'effective_from' => now()],
        ], ['policy_code', 'policy_stage'], ['policy_name', 'cooldown_days', 'is_active']);

        DB::table('account_closure_penalty_policies')->upsert([
            ['policy_family_code' => 'account_closure', 'policy_code' => 'account_closure_default', 'policy_name' => 'Account Closure Default', 'penalty_stage' => 1, 'penalty_hours' => 24, 'is_active' => 1, 'effective_from' => now()],
            ['policy_family_code' => 'account_closure', 'policy_code' => 'account_closure_default', 'policy_name' => 'Account Closure Default', 'penalty_stage' => 2, 'penalty_hours' => 48, 'is_active' => 1, 'effective_from' => now()],
            ['policy_family_code' => 'account_closure', 'policy_code' => 'account_closure_default', 'policy_name' => 'Account Closure Default', 'penalty_stage' => 3, 'penalty_hours' => 96, 'is_active' => 1, 'effective_from' => now()],
            ['policy_family_code' => 'account_closure', 'policy_code' => 'account_closure_default', 'policy_name' => 'Account Closure Default', 'penalty_stage' => 4, 'penalty_hours' => 194, 'is_active' => 1, 'effective_from' => now()],
        ], ['policy_family_code', 'policy_code', 'penalty_stage'], ['policy_name', 'penalty_hours', 'is_active']);
    }

    private function upsertLookup(string $table, array $rows, string $uniqueBy): void
    {
        $rows = array_map(fn (array $row): array => array_merge([
            'is_active' => 1,
        ], $row), $rows);
        DB::table($table)->upsert($rows, [$uniqueBy], array_keys($rows[0]));
    }
}
