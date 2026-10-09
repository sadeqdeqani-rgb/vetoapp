<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('impeachment_election_links')) {
            Schema::create('impeachment_election_links', function (Blueprint $table): void {
                $table->engine = 'InnoDB';
                $table->unsignedBigInteger('impeachment_process_id')->primary();
                $table->unsignedBigInteger('election_process_id')->unique('uq_impelection_election');
                $table->string('outcome_code', 20)->nullable();
                $table->dateTime('resolved_at')->nullable();
                $table->dateTime('created_at')->useCurrent();
                $table->foreign('impeachment_process_id', 'fk_impelection_impeach')->references('process_id')->on('processes')->restrictOnDelete()->restrictOnUpdate();
                $table->foreign('election_process_id', 'fk_impelection_election')->references('process_id')->on('processes')->restrictOnDelete()->restrictOnUpdate();
            });
        }

        foreach ([
            ['Election', 'Supporting', 'Waiting', 'IMPEACHMENT_REMOVAL_FINALIZED'],
            ['Election', 'Supporting', 'Failed', 'IMPEACHMENT_RETENTION_FINALIZED'],
            ['Impeachment', 'Publishing', 'Failed', 'IMPEACHMENT_RETAINED_AFTER_VOTE'],
        ] as [$type, $from, $to, $event]) {
            DB::table('process_transition_rules')->insertOrIgnore([
                'process_type_code' => $type, 'from_state_code' => $from, 'to_state_code' => $to,
                'event_code' => $event, 'rule_version' => 1, 'requires_support_threshold' => false,
                'support_threshold_policy_code' => null, 'is_active' => true, 'effective_from' => now(),
                'effective_to' => null, 'created_at' => now(), 'updated_at' => now(),
            ]);
        }
    }

    public function down(): void
    {
        // Lifecycle rules remain available because a deployed process may have used them.
        Schema::dropIfExists('impeachment_election_links');
    }
};
