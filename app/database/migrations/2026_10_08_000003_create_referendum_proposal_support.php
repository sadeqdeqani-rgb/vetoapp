<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('processes', function (Blueprint $table): void {
            $table->string('normalized_title', 255)->nullable()->after('title');
            $table->binary('normalized_title_hash', 32, true)->nullable()->after('normalized_title');
            $table->unsignedSmallInteger('normalization_version')->default(1)->after('normalized_title_hash');
            $table->unique(
                ['process_type_code', 'target_geographic_level_code', 'target_geographic_id', 'normalized_title_hash'],
                'uq_process_normalized_subject_scope'
            );
            $table->index(['process_type_code', 'target_geographic_level_code', 'target_geographic_id'], 'idx_process_subject_scope');
        });

        Schema::table('user_biometric_challenges', function (Blueprint $table): void {
            $table->binary('context_hash', 32, true)->nullable()->after('challenge');
        });

        Schema::create('referendum_directional_terms', function (Blueprint $table): void {
            $table->engine = 'InnoDB';
            $table->charset = 'utf8mb4';
            $table->collation = 'utf8mb4_0900_ai_ci';
            $table->id('directional_term_id');
            $table->string('term', 120);
            $table->string('normalized_term', 120);
            $table->binary('normalized_term_hash', 32, true)->unique('uq_directional_term_hash');
            $table->boolean('is_active')->default(true);
            $table->unsignedTinyInteger('created_by_admin_id')->nullable();
            $table->dateTime('created_at')->useCurrent();
            $table->dateTime('updated_at')->useCurrent()->useCurrentOnUpdate();
            $table->foreign('created_by_admin_id', 'fk_directional_term_admin')
                ->references('admin_id')->on('system_admins')->nullOnDelete()->restrictOnUpdate();
            $table->index(['is_active', 'directional_term_id'], 'idx_directional_term_active');
        });

        Schema::create('process_receipt_signing_public_keys', function (Blueprint $table): void {
            $table->engine = 'InnoDB';
            $table->charset = 'utf8mb4';
            $table->collation = 'utf8mb4_0900_ai_ci';
            $table->string('key_id', 100)->primary();
            $table->string('algorithm', 30)->default('Ed25519');
            $table->binary('public_key', 32, true);
            $table->dateTime('created_at')->useCurrent();
            $table->dateTime('retired_at')->nullable();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('process_receipt_signing_public_keys');
        Schema::dropIfExists('referendum_directional_terms');
        Schema::table('user_biometric_challenges', function (Blueprint $table): void {
            $table->dropColumn('context_hash');
        });
        Schema::table('processes', function (Blueprint $table): void {
            $table->dropUnique('uq_process_normalized_subject_scope');
            $table->dropIndex('idx_process_subject_scope');
            $table->dropColumn(['normalized_title', 'normalized_title_hash', 'normalization_version']);
        });
    }
};
