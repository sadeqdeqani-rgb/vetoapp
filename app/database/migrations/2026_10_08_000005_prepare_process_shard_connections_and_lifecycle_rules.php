<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    private const EVENTS = [
        'SUPPORT_THRESHOLD_MET',
        'SUPPORT_PERIOD_EXPIRED',
        'WAITING_PERIOD_ELAPSED',
        'VOTING_PERIOD_ELAPSED',
        'PUBLICATION_DELAY_ELAPSED',
    ];

    public function up(): void
    {
        if (! Schema::hasColumn('shard_catalog', 'connection_name')) {
            Schema::table('shard_catalog', function (Blueprint $table): void {
                $table->string('connection_name', 64)->default('mysql')->after('shard_state_code');
            });
        }

        DB::table('shard_catalog')->where('shard_id', 'primary')->update([
            'connection_name' => 'mysql',
            'updated_at' => now(),
        ]);

        DB::table('process_type_lookups')->insertOrIgnore([
            'process_type_code' => 'Referendum', 'title' => 'Referendum', 'is_active' => true,
        ]);
        DB::table('process_state_lookups')->insertOrIgnore([
            ['state_code' => 'Supporting', 'state_title' => 'Supporting', 'is_terminal' => false, 'is_active' => true, 'display_order' => 1],
            ['state_code' => 'Waiting', 'state_title' => 'Waiting', 'is_terminal' => false, 'is_active' => true, 'display_order' => 2],
            ['state_code' => 'VoteCasting', 'state_title' => 'Vote Casting', 'is_terminal' => false, 'is_active' => true, 'display_order' => 3],
            ['state_code' => 'Publishing', 'state_title' => 'Publishing', 'is_terminal' => false, 'is_active' => true, 'display_order' => 4],
            ['state_code' => 'Finalized', 'state_title' => 'Finalized', 'is_terminal' => true, 'is_active' => true, 'display_order' => 5],
            ['state_code' => 'Failed', 'state_title' => 'Failed', 'is_terminal' => true, 'is_active' => true, 'display_order' => 6],
        ]);
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

        // Store the transition vocabulary in the database alongside policy versions.
        // The lifecycle runner uses these controlled state/event codes and the
        // per-process policy snapshot; physical connection routing remains configured
        // by Laravel connection aliases, never by credentials in this catalog.
        $now = now();
        $rules = [
            ['from' => 'Supporting', 'to' => 'Waiting', 'event' => 'SUPPORT_THRESHOLD_MET', 'threshold' => true],
            ['from' => 'Supporting', 'to' => 'Failed', 'event' => 'SUPPORT_PERIOD_EXPIRED', 'threshold' => false],
            ['from' => 'Waiting', 'to' => 'VoteCasting', 'event' => 'WAITING_PERIOD_ELAPSED', 'threshold' => false],
            ['from' => 'VoteCasting', 'to' => 'Publishing', 'event' => 'VOTING_PERIOD_ELAPSED', 'threshold' => false],
            ['from' => 'Publishing', 'to' => 'Finalized', 'event' => 'PUBLICATION_DELAY_ELAPSED', 'threshold' => false],
        ];
        foreach ($rules as $rule) {
            DB::table('process_transition_rules')->insertOrIgnore([
                'process_type_code' => 'Referendum',
                'from_state_code' => $rule['from'],
                'to_state_code' => $rule['to'],
                'event_code' => $rule['event'],
                'rule_version' => 1,
                'requires_support_threshold' => $rule['threshold'],
                'support_threshold_policy_code' => $rule['threshold'] ? 'PROCESS_LIFECYCLE_V1' : null,
                'is_active' => true,
                'effective_from' => $now,
                'effective_to' => null,
                'created_at' => $now,
                'updated_at' => $now,
            ]);
        }
    }

    public function down(): void
    {
        DB::table('process_transition_rules')->where('process_type_code', 'Referendum')
            ->whereIn('event_code', self::EVENTS)->delete();
        if (Schema::hasColumn('shard_catalog', 'connection_name')) {
            Schema::table('shard_catalog', function (Blueprint $table): void {
                $table->dropColumn('connection_name');
            });
        }
    }
};
