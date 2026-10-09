<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    private const WINDOWS = [30, 60, 90, 120, 180];

    public function up(): void
    {
        if (! Schema::hasTable('process_support_gate_scopes')) Schema::create('process_support_gate_scopes', function (Blueprint $table): void {
            $table->engine = 'InnoDB';
            $table->charset = 'utf8mb4';
            $table->collation = 'utf8mb4_0900_ai_ci';
            $table->binary('gate_key', 32, true)->primary();
            $table->string('gate_kind_code', 40);
            $table->unsignedTinyInteger('target_geographic_level_code');
            $table->unsignedBigInteger('target_geographic_id');
            $table->binary('normalized_subject_hash', 32, true)->nullable();
            $table->string('normalized_subject_snapshot', 255)->nullable();
            $table->unsignedTinyInteger('failed_support_streak')->default(0);
            $table->dateTime('cooldown_until')->nullable();
            $table->dateTime('successful_at')->nullable();
            $table->dateTime('created_at')->useCurrent();
            $table->dateTime('updated_at')->useCurrent()->useCurrentOnUpdate();
            $table->index(['gate_kind_code', 'target_geographic_level_code', 'target_geographic_id', 'cooldown_until'], 'idx_support_gate_geo_cooldown');
        });

        if (! Schema::hasTable('process_support_gate_events')) Schema::create('process_support_gate_events', function (Blueprint $table): void {
            $table->engine = 'InnoDB';
            $table->charset = 'utf8mb4';
            $table->collation = 'utf8mb4_0900_ai_ci';
            $table->bigIncrements('process_support_gate_event_id');
            $table->unsignedBigInteger('process_id')->unique('uq_support_gate_event_process');
            $table->binary('gate_key', 32, true);
            $table->string('event_code', 40);
            $table->unsignedTinyInteger('failed_support_streak');
            $table->unsignedSmallInteger('cooldown_days')->default(0);
            $table->dateTime('event_at');
            $table->dateTime('cooldown_until')->nullable();
            $table->dateTime('created_at')->useCurrent();
            $table->index(['gate_key', 'event_at'], 'idx_support_gate_event_history');
        });

        $indexes = collect(DB::select('SHOW INDEX FROM processes'))->pluck('Key_name')->unique();
        Schema::table('processes', function (Blueprint $table) use ($indexes): void {
            if ($indexes->contains('uq_process_normalized_subject_scope')) $table->dropUnique('uq_process_normalized_subject_scope');
            if (! $indexes->contains('idx_process_normalized_subject_scope')) {
                $table->index(
                    ['process_type_code', 'target_geographic_level_code', 'target_geographic_id', 'normalized_title_hash'],
                    'idx_process_normalized_subject_scope'
                );
            }
        });

        $this->backfillHistory();
    }

    private function backfillHistory(): void
    {
        $processes = DB::table('processes')
            ->whereIn('process_type_code', ['Referendum', 'Impeachment'])
            ->orderBy('process_id')->get([
                'process_id', 'process_type_code', 'target_geographic_level_code', 'target_geographic_id',
                'normalized_title', 'normalized_title_hash', 'title',
            ]);

        foreach ($processes as $process) {
            $kind = $process->process_type_code === 'Referendum' ? 'REFERENDUM_SUBJECT' : 'IMPEACHMENT_SCOPE';
            $subjectHash = $kind === 'REFERENDUM_SUBJECT'
                ? (is_string($process->normalized_title_hash) ? $process->normalized_title_hash : hash('sha256', (string) $process->title, true))
                : null;
            $keyInput = $kind.'|'.(int) $process->target_geographic_level_code.'|'.(int) $process->target_geographic_id
                .($subjectHash === null ? '' : '|'.bin2hex($subjectHash));
            $key = hash('sha256', $keyInput, true);

            DB::table('process_support_gate_scopes')->insertOrIgnore([
                'gate_key' => $key,
                'gate_kind_code' => $kind,
                'target_geographic_level_code' => $process->target_geographic_level_code,
                'target_geographic_id' => $process->target_geographic_id,
                'normalized_subject_hash' => $subjectHash,
                'normalized_subject_snapshot' => $kind === 'REFERENDUM_SUBJECT' ? ($process->normalized_title ?: $process->title) : null,
                'failed_support_streak' => 0,
                'cooldown_until' => null,
                'successful_at' => null,
                'created_at' => now(),
                'updated_at' => now(),
            ]);
        }

        $resolutions = DB::table('process_states as previous')
            ->join('process_states as next', function ($join): void {
                $join->on('next.process_id', '=', 'previous.process_id')
                    ->on('next.current_state_started_at', '=', 'previous.current_state_completed_at');
            })
            ->join('processes as p', 'p.process_id', '=', 'next.process_id')
            ->where('previous.current_state_code', 'Supporting')
            ->whereIn('next.current_state_code', ['Waiting', 'Failed'])
            ->whereIn('p.process_type_code', ['Referendum', 'Impeachment'])
            ->orderBy('next.current_state_started_at')->orderBy('p.process_id')
            ->get([
                'p.process_id', 'p.process_type_code', 'p.target_geographic_level_code', 'p.target_geographic_id',
                'p.normalized_title', 'p.normalized_title_hash', 'p.title', 'next.current_state_code', 'next.current_state_started_at',
            ]);

        foreach ($resolutions as $resolution) {
            if (DB::table('process_support_gate_events')->where('process_id', $resolution->process_id)->exists()) continue;
            $kind = $resolution->process_type_code === 'Referendum' ? 'REFERENDUM_SUBJECT' : 'IMPEACHMENT_SCOPE';
            $subjectHash = $kind === 'REFERENDUM_SUBJECT'
                ? (is_string($resolution->normalized_title_hash) ? $resolution->normalized_title_hash : hash('sha256', (string) $resolution->title, true))
                : null;
            $keyInput = $kind.'|'.(int) $resolution->target_geographic_level_code.'|'.(int) $resolution->target_geographic_id
                .($subjectHash === null ? '' : '|'.bin2hex($subjectHash));
            $key = hash('sha256', $keyInput, true);
            $scope = DB::table('process_support_gate_scopes')->where('gate_key', $key)->lockForUpdate()->first();
            if ($scope === null) continue;

            if ($resolution->current_state_code === 'Waiting') {
                DB::table('process_support_gate_events')->insertOrIgnore([
                    'process_id' => $resolution->process_id, 'gate_key' => $key,
                    'event_code' => 'SUPPORT_THRESHOLD_MET', 'failed_support_streak' => 0,
                    'cooldown_days' => 0, 'event_at' => $resolution->current_state_started_at,
                    'cooldown_until' => null, 'created_at' => now(),
                ]);
                DB::table('process_support_gate_scopes')->where('gate_key', $key)->update([
                    'failed_support_streak' => 0, 'cooldown_until' => null,
                    'successful_at' => $kind === 'REFERENDUM_SUBJECT' ? ($scope->successful_at ?? $resolution->current_state_started_at) : null,
                    'updated_at' => now(),
                ]);
                continue;
            }

            $streak = min(count(self::WINDOWS), (int) $scope->failed_support_streak + 1);
            $days = self::WINDOWS[$streak - 1];
            $until = \Illuminate\Support\Carbon::parse($resolution->current_state_started_at)->addDays($days);
            DB::table('process_support_gate_events')->insertOrIgnore([
                'process_id' => $resolution->process_id, 'gate_key' => $key,
                'event_code' => 'SUPPORT_THRESHOLD_NOT_MET', 'failed_support_streak' => $streak,
                'cooldown_days' => $days, 'event_at' => $resolution->current_state_started_at,
                'cooldown_until' => $until, 'created_at' => now(),
            ]);
            DB::table('process_support_gate_scopes')->where('gate_key', $key)->update([
                'failed_support_streak' => $streak, 'cooldown_until' => $until, 'updated_at' => now(),
            ]);
        }
    }

    public function down(): void
    {
        Schema::table('processes', function (Blueprint $table): void {
            $table->dropIndex('idx_process_normalized_subject_scope');
        });
        $duplicatesExist = DB::table('processes')
            ->select('process_type_code', 'target_geographic_level_code', 'target_geographic_id', 'normalized_title_hash')
            ->groupBy('process_type_code', 'target_geographic_level_code', 'target_geographic_id', 'normalized_title_hash')
            ->havingRaw('COUNT(*) > 1')->exists();
        if ($duplicatesExist) {
            throw new \RuntimeException('Cannot restore the old unique subject index while cooldown-eligible repeat proposals exist.');
        }
        Schema::table('processes', function (Blueprint $table): void {
            $table->unique(
                ['process_type_code', 'target_geographic_level_code', 'target_geographic_id', 'normalized_title_hash'],
                'uq_process_normalized_subject_scope'
            );
        });
        Schema::dropIfExists('process_support_gate_events');
        Schema::dropIfExists('process_support_gate_scopes');
    }
};
