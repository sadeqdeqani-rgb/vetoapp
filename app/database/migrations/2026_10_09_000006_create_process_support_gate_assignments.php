<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('process_support_gate_assignments')) {
            Schema::create('process_support_gate_assignments', function (Blueprint $table): void {
                $table->engine = 'InnoDB';
                $table->charset = 'utf8mb4';
                $table->collation = 'utf8mb4_0900_ai_ci';
                $table->unsignedBigInteger('process_id')->primary();
                $table->binary('gate_key', 32, true);
                $table->dateTime('created_at')->useCurrent();
                $table->index('gate_key', 'idx_support_gate_assignment_scope');
            });
        }

        $processes = DB::table('processes')->whereIn('process_type_code', ['Referendum', 'Impeachment'])
            ->orderBy('process_id')->get([
                'process_id', 'process_type_code', 'target_geographic_level_code', 'target_geographic_id',
                'normalized_title', 'normalized_title_hash', 'title',
            ]);
        foreach ($processes as $process) {
            $kind = $process->process_type_code === 'Referendum' ? 'REFERENDUM_SUBJECT' : 'IMPEACHMENT_SCOPE';
            $subjectHash = $kind === 'REFERENDUM_SUBJECT'
                ? (is_string($process->normalized_title_hash) ? $process->normalized_title_hash : hash('sha256', (string) $process->title, true))
                : null;
            $input = $kind.'|'.(int) $process->target_geographic_level_code.'|'.(int) $process->target_geographic_id
                .($subjectHash === null ? '' : '|'.bin2hex($subjectHash));
            DB::table('process_support_gate_assignments')->insertOrIgnore([
                'process_id' => $process->process_id,
                'gate_key' => hash('sha256', $input, true),
                'created_at' => now(),
            ]);
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('process_support_gate_assignments');
    }
};
