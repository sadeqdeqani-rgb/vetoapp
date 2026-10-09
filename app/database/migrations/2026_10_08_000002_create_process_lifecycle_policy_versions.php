<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('process_lifecycle_policy_versions', function (Blueprint $table): void {
            $table->engine = 'InnoDB';
            $table->charset = 'utf8mb4';
            $table->collation = 'utf8mb4_0900_ai_ci';
            $table->id('process_lifecycle_policy_version_id');
            $table->unsignedSmallInteger('version_number')->unique('uq_process_lifecycle_version_no');
            $table->string('support_threshold_policy_code', 50);
            $table->unsignedInteger('threshold_rate_ppm');
            $table->string('rounding_mode_code', 30)->default('CEIL');
            $table->unsignedBigInteger('min_support_count')->default(0);
            $table->unsignedInteger('support_period_seconds');
            $table->unsignedInteger('waiting_period_seconds');
            $table->unsignedInteger('voting_period_seconds');
            $table->unsignedInteger('publication_delay_seconds');
            $table->boolean('is_active')->default(false);
            $table->unsignedTinyInteger('active_policy_marker')->nullable();
            $table->dateTime('effective_from');
            $table->dateTime('effective_to')->nullable();
            $table->unsignedTinyInteger('created_by_admin_id')->nullable();
            $table->dateTime('created_at')->useCurrent();
            $table->foreign('support_threshold_policy_code', 'fk_lifecycle_support_policy')
                ->references('support_threshold_policy_code')->on('support_threshold_policy_lookups')
                ->restrictOnDelete()->restrictOnUpdate();
            $table->foreign('created_by_admin_id', 'fk_lifecycle_created_admin')
                ->references('admin_id')->on('system_admins')
                ->restrictOnDelete()->restrictOnUpdate();
            $table->index(['is_active', 'effective_from', 'effective_to'], 'idx_process_lifecycle_policy_effective');
        });
        if (DB::getDriverName() === 'mysql') {
            DB::statement('ALTER TABLE process_lifecycle_policy_versions
                ADD CONSTRAINT chk_lifecycle_threshold_rate CHECK (threshold_rate_ppm BETWEEN 1 AND 1000000),
                ADD CONSTRAINT chk_lifecycle_effective_window CHECK (effective_to IS NULL OR effective_to > effective_from)');
        }

        if (DB::getDriverName() === 'mysql') {
            DB::statement("ALTER TABLE process_lifecycle_policy_versions
                MODIFY active_policy_marker TINYINT UNSIGNED
                    GENERATED ALWAYS AS (CASE WHEN is_active = 1 THEN 1 ELSE NULL END) STORED,
                ADD UNIQUE KEY uq_process_lifecycle_policy_active (active_policy_marker)");
        } else {
            Schema::table('process_lifecycle_policy_versions', function (Blueprint $table): void {
                $table->unique('active_policy_marker', 'uq_process_lifecycle_policy_active');
            });
        }

        Schema::table('processes', function (Blueprint $table): void {
            $table->unsignedBigInteger('process_lifecycle_policy_version_id')->nullable()->after('process_type_code');
            $table->foreign('process_lifecycle_policy_version_id', 'fk_process_lifecycle_policy')
                ->references('process_lifecycle_policy_version_id')->on('process_lifecycle_policy_versions')
                ->restrictOnDelete()->restrictOnUpdate();
            $table->index('process_lifecycle_policy_version_id', 'idx_process_lifecycle_policy');
        });
    }

    public function down(): void
    {
        Schema::table('processes', function (Blueprint $table): void {
            $table->dropForeign('fk_process_lifecycle_policy');
            $table->dropIndex('idx_process_lifecycle_policy');
            $table->dropColumn('process_lifecycle_policy_version_id');
        });
        Schema::dropIfExists('process_lifecycle_policy_versions');
    }
};
