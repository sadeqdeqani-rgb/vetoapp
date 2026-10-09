<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('shard_catalog', function (Blueprint $table): void {
            $table->engine = 'InnoDB';
            $table->charset = 'utf8mb4';
            $table->collation = 'utf8mb4_0900_ai_ci';
            $table->string('shard_id', 50)->primary();
            $table->string('shard_state_code', 20);
            $table->string('schema_version', 50);
            $table->dateTime('created_at', 6)->useCurrent();
            $table->dateTime('updated_at', 6)->useCurrent()->useCurrentOnUpdate();
            $table->index(['shard_state_code', 'schema_version'], 'idx_shard_catalog_state_schema');
        });

        Schema::create('process_shard_placements', function (Blueprint $table): void {
            $table->engine = 'InnoDB';
            $table->charset = 'utf8mb4';
            $table->collation = 'utf8mb4_0900_ai_ci';
            $table->unsignedBigInteger('process_id')->autoIncrement()->primary();
            $table->string('shard_id', 50);
            $table->string('placement_state_code', 20);
            $table->unsignedSmallInteger('placement_version')->default(1);
            $table->dateTime('assigned_at', 6);
            $table->dateTime('activated_at', 6)->nullable();
            $table->dateTime('updated_at', 6)->useCurrent()->useCurrentOnUpdate();
            $table->foreign('shard_id', 'fk_psp_shard')
                ->references('shard_id')->on('shard_catalog')->restrictOnDelete()->restrictOnUpdate();
            $table->index(['shard_id', 'placement_state_code'], 'idx_psp_shard_state');
        });

        Schema::create('process_shard_placement_history', function (Blueprint $table): void {
            $table->engine = 'InnoDB';
            $table->charset = 'utf8mb4';
            $table->collation = 'utf8mb4_0900_ai_ci';
            $table->bigIncrements('placement_history_id');
            $table->unsignedBigInteger('process_id');
            $table->unsignedSmallInteger('placement_version');
            $table->unsignedSmallInteger('placement_event_no');
            $table->string('source_shard_id', 50)->nullable();
            $table->string('destination_shard_id', 50);
            $table->string('operation_event_code', 30);
            $table->unsignedBigInteger('verified_last_sequence_no')->nullable();
            $table->binary('verified_last_hash', 32)->nullable();
            $table->unsignedBigInteger('verified_merkle_checkpoint_no')->nullable();
            $table->dateTime('created_at', 6)->useCurrent();
            $table->dateTime('completed_at', 6)->nullable();
            $table->unique(
                ['process_id', 'placement_version', 'placement_event_no'],
                'uq_psph_process_version_event'
            );
            $table->index(['process_id', 'placement_version'], 'idx_psph_process_version');
        });

        DB::table('shard_catalog')->insert([
            'shard_id' => 'primary',
            'shard_state_code' => 'ONLINE',
            'schema_version' => 'process-schema-v43',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $now = now();
        DB::table('process_shard_placements')->insertUsing(
            ['process_id', 'shard_id', 'placement_state_code', 'placement_version', 'assigned_at', 'activated_at', 'updated_at'],
            DB::table('processes')->selectRaw(
                "process_id, 'primary', 'ACTIVE', 1, ?, ?, ?",
                [$now, $now, $now]
            )
        );

        DB::table('process_shard_placement_history')->insertUsing(
            ['process_id', 'placement_version', 'placement_event_no', 'source_shard_id', 'destination_shard_id', 'operation_event_code', 'created_at', 'completed_at'],
            DB::table('processes')->selectRaw(
                "process_id, 1, 1, NULL, 'primary', 'PLACEMENT_PREPARED', ?, ?",
                [$now, $now]
            )
        );
        DB::table('process_shard_placement_history')->insertUsing(
            ['process_id', 'placement_version', 'placement_event_no', 'source_shard_id', 'destination_shard_id', 'operation_event_code', 'created_at', 'completed_at'],
            DB::table('processes')->selectRaw(
                "process_id, 1, 2, NULL, 'primary', 'CUTOVER', ?, ?",
                [$now, $now]
            )
        );
    }

    public function down(): void
    {
        Schema::dropIfExists('process_shard_placement_history');
        Schema::dropIfExists('process_shard_placements');
        Schema::dropIfExists('shard_catalog');
    }
};
