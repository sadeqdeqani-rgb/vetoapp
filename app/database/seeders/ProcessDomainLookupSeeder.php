<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class ProcessDomainLookupSeeder extends Seeder
{
    public function run(): void
    {
        DB::table('process_state_lookups')->upsert([
            ['state_code' => 'Supporting', 'state_title' => 'Supporting', 'is_terminal' => false, 'is_active' => true, 'display_order' => 1],
            ['state_code' => 'Waiting', 'state_title' => 'Waiting', 'is_terminal' => false, 'is_active' => true, 'display_order' => 2],
            ['state_code' => 'VoteCasting', 'state_title' => 'Vote Casting', 'is_terminal' => false, 'is_active' => true, 'display_order' => 3],
            ['state_code' => 'Publishing', 'state_title' => 'Publishing', 'is_terminal' => false, 'is_active' => true, 'display_order' => 4],
            ['state_code' => 'Finalized', 'state_title' => 'Finalized', 'is_terminal' => true, 'is_active' => true, 'display_order' => 5],
            ['state_code' => 'Failed', 'state_title' => 'Failed', 'is_terminal' => true, 'is_active' => true, 'display_order' => 6],
            ['state_code' => 'Terminated', 'state_title' => 'Terminated', 'is_terminal' => true, 'is_active' => true, 'display_order' => 7],
        ], ['state_code'], ['state_title', 'is_terminal', 'is_active', 'display_order']);

        DB::table('process_type_lookups')->upsert([
            ['process_type_code' => 'Referendum', 'title' => 'Referendum', 'is_active' => true],
            ['process_type_code' => 'Election', 'title' => 'Election', 'is_active' => true],
            ['process_type_code' => 'Impeachment', 'title' => 'Impeachment', 'is_active' => true],
        ], ['process_type_code'], ['title', 'is_active']);

        DB::table('vote_token_state_lookups')->upsert([
            ['token_state_code' => 'ISSUED', 'title' => 'Issued', 'is_terminal' => false],
            ['token_state_code' => 'USED', 'title' => 'Used', 'is_terminal' => true],
            ['token_state_code' => 'REVOKED', 'title' => 'Revoked', 'is_terminal' => true],
            ['token_state_code' => 'EXPIRED', 'title' => 'Expired', 'is_terminal' => true],
        ], ['token_state_code'], ['title', 'is_terminal']);

        DB::table('receipt_type_lookups')->upsert([
            ['receipt_type_code' => 'SUPPORT', 'title' => 'Support', 'is_active' => true],
            ['receipt_type_code' => 'VOTE', 'title' => 'Vote', 'is_active' => true],
        ], ['receipt_type_code'], ['title', 'is_active']);

        // Seed the initial admin-managed lifecycle policy once. Later changes are
        // append-only versions created through AdminPolicyController.
        DB::table('support_threshold_policy_lookups')->insertOrIgnore([
            'support_threshold_policy_code' => 'PROCESS_LIFECYCLE_V1',
            'policy_name' => 'سیاست چرخه فرایند نسخه ۱',
            'threshold_rate_ppm' => 200000,
            'rounding_mode_code' => 'CEIL',
            'min_support_count' => 0,
            'is_active' => true,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        if (! DB::table('process_lifecycle_policy_versions')->exists()) {
            DB::table('process_lifecycle_policy_versions')->insert([
                'version_number' => 1,
                'support_threshold_policy_code' => 'PROCESS_LIFECYCLE_V1',
                'threshold_rate_ppm' => 200000,
                'rounding_mode_code' => 'CEIL',
                'min_support_count' => 0,
                'support_period_seconds' => 30 * 86400,
                'waiting_period_seconds' => 30 * 86400,
                'voting_period_seconds' => 7 * 86400,
                'publication_delay_seconds' => 24 * 3600,
                'is_active' => true,
                'effective_from' => now(),
                'effective_to' => null,
                'created_by_admin_id' => null,
                'created_at' => now(),
            ]);
        }
    }
}
