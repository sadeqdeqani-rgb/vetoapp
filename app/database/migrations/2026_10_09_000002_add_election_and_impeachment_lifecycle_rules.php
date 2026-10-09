<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    private const TYPES = ['Referendum', 'Election', 'Impeachment'];

    public function up(): void
    {
        $now = now();
        $rules = [
            ['Supporting', 'Waiting', 'SUPPORT_THRESHOLD_MET', true],
            ['Supporting', 'Failed', 'SUPPORT_PERIOD_EXPIRED', false],
            ['Waiting', 'VoteCasting', 'WAITING_PERIOD_ELAPSED', false],
            ['VoteCasting', 'Publishing', 'VOTING_PERIOD_ELAPSED', false],
            ['VoteCasting', 'Failed', 'EMPTY_VOTING_PERIOD', false],
            ['Publishing', 'Finalized', 'PUBLICATION_DELAY_ELAPSED', false],
        ];

        foreach (self::TYPES as $type) {
            DB::table('process_type_lookups')->insertOrIgnore([
                'process_type_code' => $type,
                'title' => $type,
                'is_active' => true,
            ]);
            foreach ($rules as [$from, $to, $event, $threshold]) {
                DB::table('process_transition_rules')->insertOrIgnore([
                    'process_type_code' => $type,
                    'from_state_code' => $from,
                    'to_state_code' => $to,
                    'event_code' => $event,
                    'rule_version' => 1,
                    'requires_support_threshold' => $threshold,
                    'support_threshold_policy_code' => $threshold ? 'PROCESS_LIFECYCLE_V1' : null,
                    'is_active' => true,
                    'effective_from' => $now,
                    'effective_to' => null,
                    'created_at' => $now,
                    'updated_at' => $now,
                ]);
            }
        }
    }

    public function down(): void
    {
        // Transition vocabulary may already be used by created processes. Keep
        // those rules in place on rollback; disabling them could strand a live box.
    }
};
