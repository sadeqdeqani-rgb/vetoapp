<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    private function configure(Blueprint $table): void
    {
        $table->engine = 'InnoDB';
        $table->charset = 'utf8mb4';
        $table->collation = 'utf8mb4_0900_ai_ci';
    }

    public function up(): void
    {
        Schema::create('system_admins', function (Blueprint $table) {
            $this->configure($table);
            $table->unsignedTinyInteger('admin_id')->autoIncrement();
            $table->binary('admin_uuid', 16)->unique();
            $table->string('username', 50)->unique();
            $table->string('password_hash', 255);
            $table->text('public_key_pem');
            $table->boolean('is_active')->default(true);
            $table->dateTime('created_at')->useCurrent();
            $table->dateTime('updated_at')->useCurrent()->useCurrentOnUpdate();
        });

        Schema::create('admin_activity_logs', function (Blueprint $table) {
            $this->configure($table);
            $table->id('log_id');
            $table->unsignedTinyInteger('admin_id');
            $table->string('action_name', 100);
            $table->string('target_table', 64);
            $table->string('target_id', 128)->nullable();
            $table->json('payload_before')->nullable();
            $table->json('payload_after')->nullable();
            $table->binary('digital_signature', 64)->nullable();
            $table->string('client_ip', 45);
            $table->string('user_agent', 512)->nullable();
            $table->dateTime('created_at')->useCurrent();
            $table->foreign('admin_id')->references('admin_id')->on('system_admins');
            $table->index(['admin_id', 'created_at'], 'idx_admin_activity_admin_created');
            $table->index(['action_name', 'created_at'], 'idx_admin_activity_action_created');
            $table->index(['target_table', 'target_id'], 'idx_admin_activity_target');
        });

        Schema::create('countries', function (Blueprint $table) {
            $this->configure($table);
            $table->unsignedSmallInteger('country_id')->autoIncrement();
            $table->unsignedSmallInteger('country_code')->unique();
            $table->string('name_fa', 100);
            $table->boolean('is_active')->default(true);
            $table->dateTime('created_at')->useCurrent();
            $table->dateTime('updated_at')->useCurrent()->useCurrentOnUpdate();
            $table->index('is_active', 'idx_country_active');
        });

        Schema::create('provinces', function (Blueprint $table) {
            $this->configure($table);
            $table->unsignedSmallInteger('province_id')->autoIncrement();
            $table->unsignedSmallInteger('country_id');
            $table->unsignedSmallInteger('province_code')->unique();
            $table->string('name_fa', 100);
            $table->boolean('is_active')->default(true);
            $table->dateTime('created_at')->useCurrent();
            $table->dateTime('updated_at')->useCurrent()->useCurrentOnUpdate();
            $table->foreign('country_id')->references('country_id')->on('countries');
            $table->index(['country_id', 'is_active'], 'idx_province_country_active');
        });

        Schema::create('counties', function (Blueprint $table) {
            $this->configure($table);
            $table->unsignedSmallInteger('county_id')->autoIncrement();
            $table->unsignedSmallInteger('province_id');
            $table->unsignedSmallInteger('county_code')->unique();
            $table->string('name_fa', 100);
            $table->boolean('is_active')->default(true);
            $table->dateTime('created_at')->useCurrent();
            $table->dateTime('updated_at')->useCurrent()->useCurrentOnUpdate();
            $table->foreign('province_id')->references('province_id')->on('provinces');
            $table->index(['province_id', 'is_active'], 'idx_county_province_active');
        });

        Schema::create('settlements', function (Blueprint $table) {
            $this->configure($table);
            $table->increments('settlement_id');
            $table->unsignedSmallInteger('county_id');
            $table->unsignedInteger('settlement_code')->unique();
            $table->string('name_fa', 100);
            $table->boolean('is_active')->default(true);
            $table->dateTime('created_at')->useCurrent();
            $table->dateTime('updated_at')->useCurrent()->useCurrentOnUpdate();
            $table->foreign('county_id')->references('county_id')->on('counties');
            $table->index(['county_id', 'is_active'], 'idx_settlement_county_active');
        });

        Schema::create('geographic_level_lookups', function (Blueprint $table) {
            $this->configure($table);
            $table->unsignedTinyInteger('geographic_level_code')->primary();
            $table->string('geographic_level_title', 100);
            $table->unsignedTinyInteger('hierarchy_rank')->unique();
            $table->unsignedTinyInteger('lock_order');
            $table->boolean('is_active')->default(true);
            $table->dateTime('created_at')->useCurrent();
            $table->dateTime('updated_at')->useCurrent()->useCurrentOnUpdate();
        });

        Schema::create('otp_state_lookups', function (Blueprint $table) {
            $this->configure($table);
            $table->string('state_code', 15)->primary();
            $table->string('state_name', 100);
            $table->boolean('is_active')->default(true);
            $table->unsignedInteger('display_order')->default(0);
        });

        Schema::create('otp_purpose_lookups', function (Blueprint $table) {
            $this->configure($table);
            $table->string('purpose_code', 25)->primary();
            $table->string('purpose_name', 100);
            $table->boolean('is_active')->default(true);
            $table->unsignedInteger('display_order')->default(0);
        });

        Schema::create('otp_throttle_window_state_lookups', function (Blueprint $table) {
            $this->configure($table);
            $table->string('state_code', 15)->primary();
            $table->string('state_name', 100);
            $table->boolean('is_active')->default(true);
            $table->unsignedInteger('display_order')->default(0);
        });

        Schema::create('integration_inbox_status_lookups', function (Blueprint $table) {
            $this->configure($table);
            $table->string('status_code', 20)->primary();
            $table->string('status_name', 100);
            $table->boolean('is_active')->default(true);
            $table->unsignedInteger('display_order')->default(0);
        });

        Schema::create('registration_draft_state_lookups', function (Blueprint $table) {
            $this->configure($table);
            $table->string('state_code', 15)->primary();
            $table->string('state_name', 100);
            $table->boolean('is_active')->default(true);
            $table->boolean('is_default')->default(false);
            $table->unsignedInteger('display_order')->unique();
        });

        Schema::create('registration_draft_step_lookups', function (Blueprint $table) {
            $this->configure($table);
            $table->string('step_code', 30)->primary();
            $table->string('step_name', 100);
            $table->boolean('is_active')->default(true);
            $table->boolean('is_default')->default(false);
            $table->unsignedInteger('display_order')->unique();
        });

        Schema::create('auth_session_state_lookups', function (Blueprint $table) {
            $this->configure($table);
            $table->string('state_code', 20)->primary();
            $table->string('state_name', 100);
            $table->boolean('is_active')->default(true);
            $table->unsignedInteger('display_order')->default(0);
            $table->dateTime('created_at')->useCurrent();
            $table->dateTime('updated_at')->useCurrent()->useCurrentOnUpdate();
        });

        Schema::create('system_state_lookups', function (Blueprint $table) {
            $this->configure($table);
            $table->unsignedTinyInteger('state_code')->primary();
            $table->string('state_name', 100);
            $table->string('description', 255)->nullable();
        });

        Schema::create('national_id_area_eligibilities', function (Blueprint $table) {
            $this->configure($table);
            $table->unsignedSmallInteger('national_id_prefix_3')->primary();
            $table->unsignedSmallInteger('first_range_from');
            $table->unsignedSmallInteger('first_range_to');
            $table->unsignedSmallInteger('second_range_from');
            $table->unsignedSmallInteger('second_range_to');
            $table->dateTime('created_at')->useCurrent();
            $table->dateTime('updated_at')->useCurrent()->useCurrentOnUpdate();
        });

        Schema::create('geo_cooldown_policies', function (Blueprint $table) {
            $this->configure($table);
            $table->unsignedSmallInteger('policy_id')->autoIncrement();
            $table->string('policy_code', 50);
            $table->string('policy_name', 150);
            $table->string('description', 500)->nullable();
            $table->unsignedTinyInteger('policy_stage');
            $table->unsignedTinyInteger('max_changes_allowed')->nullable();
            $table->unsignedSmallInteger('window_days')->nullable();
            $table->unsignedSmallInteger('cooldown_days');
            $table->boolean('is_active')->default(true);
            $table->dateTime('effective_from');
            $table->dateTime('effective_to')->nullable();
            $table->dateTime('created_at')->useCurrent();
            $table->dateTime('updated_at')->useCurrent()->useCurrentOnUpdate();
            $table->unique(['policy_code', 'policy_stage'], 'uq_geo_policy_code_stage');
            $table->index(['is_active', 'effective_from', 'effective_to'], 'idx_geo_policy_active_effective');
        });

        Schema::create('account_closure_penalty_policies', function (Blueprint $table) {
            $this->configure($table);
            $table->unsignedSmallInteger('policy_id')->autoIncrement();
            $table->string('policy_family_code', 50);
            $table->string('policy_code', 50);
            $table->string('policy_name', 150);
            $table->string('description', 500)->nullable();
            $table->unsignedTinyInteger('penalty_stage');
            $table->unsignedInteger('penalty_hours');
            $table->string('trigger_scope', 50)->default('account_closure');
            $table->boolean('is_active')->default(true);
            $table->dateTime('effective_from');
            $table->dateTime('effective_to')->nullable();
            $table->dateTime('created_at')->useCurrent();
            $table->dateTime('updated_at')->useCurrent()->useCurrentOnUpdate();
            $table->unique(
                ['policy_family_code', 'policy_code', 'penalty_stage'],
                'uq_closure_policy_family_code_stage'
            );
            $table->index(['is_active', 'effective_from', 'effective_to'], 'idx_closure_policy_active_effective');
        });

        DB::statement("ALTER TABLE national_id_area_eligibilities
            ADD CONSTRAINT chk_national_first_range CHECK (first_range_from <= first_range_to),
            ADD CONSTRAINT chk_national_second_range CHECK (second_range_from <= second_range_to),
            ADD CONSTRAINT chk_national_first_max CHECK (first_range_to <= 999),
            ADD CONSTRAINT chk_national_second_max CHECK (second_range_to <= 999)");
    }

    public function down(): void
    {
        Schema::dropIfExists('account_closure_penalty_policies');
        Schema::dropIfExists('geo_cooldown_policies');
        Schema::dropIfExists('national_id_area_eligibilities');
        Schema::dropIfExists('system_state_lookups');
        Schema::dropIfExists('auth_session_state_lookups');
        Schema::dropIfExists('registration_draft_step_lookups');
        Schema::dropIfExists('registration_draft_state_lookups');
        Schema::dropIfExists('integration_inbox_status_lookups');
        Schema::dropIfExists('otp_throttle_window_state_lookups');
        Schema::dropIfExists('otp_purpose_lookups');
        Schema::dropIfExists('otp_state_lookups');
        Schema::dropIfExists('geographic_level_lookups');
        Schema::dropIfExists('settlements');
        Schema::dropIfExists('counties');
        Schema::dropIfExists('provinces');
        Schema::dropIfExists('countries');
        Schema::dropIfExists('admin_activity_logs');
        Schema::dropIfExists('system_admins');
    }
};
