<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        DB::table('process_transition_rules')->insertOrIgnore([
            'process_type_code' => 'Referendum',
            'from_state_code' => 'VoteCasting',
            'to_state_code' => 'Failed',
            'event_code' => 'EMPTY_VOTING_PERIOD',
            'rule_version' => 1,
            'requires_support_threshold' => false,
            'support_threshold_policy_code' => null,
            'is_active' => true,
            'effective_from' => now(),
            'effective_to' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    public function down(): void
    {
        DB::table('process_transition_rules')
            ->where('process_type_code', 'Referendum')
            ->where('from_state_code', 'VoteCasting')
            ->where('to_state_code', 'Failed')
            ->where('event_code', 'EMPTY_VOTING_PERIOD')
            ->update(['is_active' => false, 'effective_to' => now(), 'updated_at' => now()]);
    }
};
