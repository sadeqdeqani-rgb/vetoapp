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
        foreach ([
            'country_active_user_counters' => 'country_id',
            'province_active_user_counters' => 'province_id',
            'county_active_user_counters' => 'county_id',
            'settlement_active_user_counters' => 'settlement_id',
        ] as $tableName => $key) {
            Schema::create($tableName, function (Blueprint $table) use ($key) {
                $this->configure($table);
                $table->unsignedSmallInteger($key)->primary();
                $table->unsignedBigInteger('active_user_count')->default(0);
                $table->dateTime('updated_at')->useCurrent()->useCurrentOnUpdate();
            });
        }

        Schema::table('country_active_user_counters', function (Blueprint $table) {
            $table->foreign('country_id')->references('country_id')->on('countries');
        });
        Schema::table('province_active_user_counters', function (Blueprint $table) {
            $table->foreign('province_id')->references('province_id')->on('provinces');
        });
        Schema::table('county_active_user_counters', function (Blueprint $table) {
            $table->foreign('county_id')->references('county_id')->on('counties');
        });
        Schema::table('settlement_active_user_counters', function (Blueprint $table) {
            $table->foreign('settlement_id')->references('settlement_id')->on('settlements');
        });

        Schema::create('user_profiles', function (Blueprint $table) {
            $this->configure($table);
            $table->unsignedBigInteger('user_id')->primary();
            $table->binary('mobile_hash', 32)->nullable()->unique();
            $table->binary('mobile_encrypted', 255)->nullable();
            $table->binary('national_id_hash', 32)->nullable()->unique();
            $table->binary('national_id_encrypted', 255)->nullable();
            $table->unsignedInteger('settlement_id');
            $table->unsignedSmallInteger('county_id');
            $table->unsignedSmallInteger('province_id');
            $table->unsignedSmallInteger('country_id');
            $table->boolean('is_active')->default(true);
            $table->dateTime('created_at')->useCurrent();
            $table->dateTime('geo_updated_at')->useCurrent();
            $table->dateTime('initial_geo_selected_at')->useCurrent();
            $table->foreign('settlement_id')->references('settlement_id')->on('settlements');
            $table->foreign('county_id')->references('county_id')->on('counties');
            $table->foreign('province_id')->references('province_id')->on('provinces');
            $table->foreign('country_id')->references('country_id')->on('countries');
            $table->index(['country_id', 'province_id', 'county_id'], 'idx_user_profile_geo_chain');
            $table->index(['settlement_id', 'is_active'], 'idx_user_profile_settlement_active');
        });

        Schema::create('user_accounts', function (Blueprint $table) {
            $this->configure($table);
            $table->unsignedBigInteger('user_id')->primary();
            $table->string('password_hash', 255)->nullable();
            $table->string('account_status', 15)->default('Active');
            $table->boolean('mfa_required')->default(false);
            $table->unsignedTinyInteger('failed_login_count')->default(0);
            $table->unsignedInteger('lockout_count')->default(0);
            $table->dateTime('last_failed_login_at')->nullable();
            $table->dateTime('last_locked_at')->nullable();
            $table->dateTime('locked_until')->nullable();
            $table->dateTime('password_reset_completed_at')->nullable();
            $table->dateTime('password_changed_at')->nullable();
            $table->dateTime('created_at')->useCurrent();
            $table->dateTime('updated_at')->useCurrent()->useCurrentOnUpdate();
            $table->foreign('user_id')->references('user_id')->on('user_profiles');
            $table->index(['account_status', 'locked_until'], 'idx_user_account_status_lock');
        });

        Schema::create('registration_drafts', function (Blueprint $table) {
            $this->configure($table);
            $table->id('registration_draft_id');
            $table->string('state_code', 15);
            $table->string('step_code', 30);
            $table->string('idempotency_key', 80)->unique();
            $table->binary('mobile_hash', 32);
            $table->binary('mobile_encrypted', 255)->nullable();
            $table->binary('national_id_hash', 32)->nullable();
            $table->binary('national_id_encrypted', 255)->nullable();
            $table->unsignedSmallInteger('key_version')->nullable();
            $table->unsignedInteger('settlement_id')->nullable();
            $table->dateTime('created_at')->useCurrent();
            $table->dateTime('updated_at')->useCurrent()->useCurrentOnUpdate();
            $table->dateTime('expires_at');
            $table->dateTime('completed_at')->nullable();
            $table->foreign('state_code')->references('state_code')->on('registration_draft_state_lookups');
            $table->foreign('step_code')->references('step_code')->on('registration_draft_step_lookups');
            $table->foreign('settlement_id')->references('settlement_id')->on('settlements');
            $table->index(['state_code', 'expires_at'], 'idx_registration_draft_state_expiry');
            $table->index('mobile_hash', 'idx_registration_draft_mobile_hash');
            $table->index('settlement_id', 'idx_registration_draft_settlement');
        });

        if (DB::getDriverName() === 'mysql') {
            DB::statement("
                ALTER TABLE registration_drafts
                ADD active_mobile_hash BINARY(32)
                    GENERATED ALWAYS AS (
                        CASE WHEN state_code = 'Initiated' THEN mobile_hash ELSE NULL END
                    ) STORED,
                ADD active_national_id_hash BINARY(32)
                    GENERATED ALWAYS AS (
                        CASE
                            WHEN state_code = 'Initiated'
                             AND step_code <> 'Mobile_Verification'
                            THEN national_id_hash
                            ELSE NULL
                        END
                    ) STORED,
                ADD UNIQUE KEY uq_registration_draft_active_mobile (active_mobile_hash),
                ADD UNIQUE KEY uq_registration_draft_active_national_id (active_national_id_hash)
            ");
        } else {
            // SQLite is used for fast tests and does not share MySQL's generated-column syntax.
            Schema::table('registration_drafts', function (Blueprint $table): void {
                $table->binary('active_mobile_hash', 32)->nullable();
                $table->binary('active_national_id_hash', 32)->nullable();
                $table->unique('active_mobile_hash', 'uq_registration_draft_active_mobile');
                $table->unique('active_national_id_hash', 'uq_registration_draft_active_national_id');
            });
        }

        Schema::create('user_geo_change_logs', function (Blueprint $table) {
            $this->configure($table);
            $table->id('geo_change_log_id');
            $table->unsignedBigInteger('user_id');
            foreach (['old', 'new'] as $prefix) {
                $table->unsignedInteger($prefix.'_settlement_id');
                $table->unsignedSmallInteger($prefix.'_county_id');
                $table->unsignedSmallInteger($prefix.'_province_id');
                $table->unsignedSmallInteger($prefix.'_country_id');
            }
            $table->string('change_source', 20);
            $table->unsignedSmallInteger('policy_id')->nullable();
            $table->string('bypass_reason', 255)->nullable();
            $table->dateTime('changed_at')->useCurrent();
            $table->foreign('user_id')->references('user_id')->on('user_profiles');
            $table->foreign('policy_id')->references('policy_id')->on('geo_cooldown_policies');
            foreach (['old', 'new'] as $prefix) {
                $table->foreign($prefix.'_settlement_id')->references('settlement_id')->on('settlements');
                $table->foreign($prefix.'_county_id')->references('county_id')->on('counties');
                $table->foreign($prefix.'_province_id')->references('province_id')->on('provinces');
                $table->foreign($prefix.'_country_id')->references('country_id')->on('countries');
            }
            $table->index(['user_id', 'changed_at'], 'idx_geo_change_user_changed');
            $table->index(
                ['new_country_id', 'new_province_id', 'new_county_id', 'new_settlement_id'],
                'idx_geo_change_new_geo'
            );
        });

        Schema::create('national_id_cooldown_ledgers', function (Blueprint $table) {
            $this->configure($table);
            $table->binary('national_id_hash', 32)->primary();
            $table->unsignedTinyInteger('closure_count')->default(1);
            $table->unsignedSmallInteger('policy_id');
            $table->unsignedInteger('cooldown_hours');
            $table->dateTime('cooldown_until');
            $table->dateTime('last_closed_at')->useCurrent();
            $table->dateTime('created_at')->useCurrent();
            $table->dateTime('updated_at')->useCurrent()->useCurrentOnUpdate();
            $table->foreign('policy_id')->references('policy_id')->on('account_closure_penalty_policies');
            $table->index('cooldown_until', 'idx_national_cooldown_until');
            $table->index('policy_id', 'idx_national_cooldown_policy');
        });

        Schema::create('security_policies', function (Blueprint $table) {
            $this->configure($table);
            $table->unsignedTinyInteger('policy_id')->autoIncrement();
            $table->boolean('is_active')->default(false);
            $table->unsignedTinyInteger('max_failed_attempts')->default(5);
            $table->unsignedInteger('base_lockout_seconds')->default(900);
            $table->decimal('progressive_factor', 3, 1)->default(2.0);
            $table->unsignedInteger('max_lockout_seconds')->default(86400);
            $table->dateTime('created_at')->useCurrent();
            $table->dateTime('updated_at')->useCurrent()->useCurrentOnUpdate();
        });
        if (DB::getDriverName() === 'mysql') {
            DB::statement("
                ALTER TABLE security_policies
                ADD active_marker TINYINT
                    GENERATED ALWAYS AS (CASE WHEN is_active = 1 THEN 1 ELSE NULL END) STORED,
                ADD UNIQUE KEY uq_security_policy_active (active_marker)
            ");
        } else {
            Schema::table('security_policies', function (Blueprint $table): void {
                $table->unsignedTinyInteger('active_marker')->nullable();
                $table->unique('active_marker', 'uq_security_policy_active');
            });
        }

        Schema::create('user_login_audit_logs', function (Blueprint $table) {
            $this->configure($table);
            $table->id('log_id');
            $table->unsignedBigInteger('user_id');
            $table->dateTime('attempted_at')->useCurrent();
            $table->string('login_status', 15);
            $table->string('failure_reason', 50)->nullable();
            $table->string('ip_address', 45);
            $table->string('user_agent', 512);
            $table->foreign('user_id')->references('user_id')->on('user_accounts');
            $table->index(['user_id', 'attempted_at'], 'idx_login_audit_user_time');
            $table->index(['ip_address', 'attempted_at'], 'idx_login_audit_ip_time');
        });

        Schema::create('user_biometric_credentials', function (Blueprint $table) {
            $this->configure($table);
            $table->id('biometric_credential_id');
            $table->unsignedBigInteger('user_id');
            $table->binary('credential_id', 255)->nullable()->unique();
            $table->string('device_identifier', 128)->nullable();
            $table->string('device_model', 100)->nullable();
            $table->binary('aaguid', 16)->nullable();
            $table->binary('public_key')->nullable();
            $table->binary('public_key_sha256', 32)->nullable();
            $table->string('key_algorithm', 15)->nullable();
            $table->boolean('is_active')->default(false);
            $table->boolean('is_default')->default(false);
            $table->unsignedInteger('sign_count')->default(0);
            $table->dateTime('last_used_at')->nullable();
            $table->dateTime('created_at')->useCurrent();
            $table->dateTime('updated_at')->useCurrent()->useCurrentOnUpdate();
            $table->boolean('is_anonymized')->default(false);
            $table->dateTime('anonymized_at')->nullable();
            $table->foreign('user_id')->references('user_id')->on('user_profiles');
            $table->index(['user_id', 'is_active'], 'idx_biometric_user_active');
            $table->index('public_key_sha256', 'idx_biometric_public_hash');
        });
        if (DB::getDriverName() === 'mysql') {
            DB::statement("
                ALTER TABLE user_biometric_credentials
                ADD active_user_id BIGINT UNSIGNED
                    GENERATED ALWAYS AS (CASE WHEN is_active = 1 THEN user_id ELSE NULL END) STORED,
                ADD default_user_id BIGINT UNSIGNED
                    GENERATED ALWAYS AS (CASE WHEN is_default = 1 THEN user_id ELSE NULL END) STORED,
                ADD UNIQUE KEY uq_biometric_active_user (active_user_id),
                ADD UNIQUE KEY uq_biometric_default_user (default_user_id)
            ");
        } else {
            Schema::table('user_biometric_credentials', function (Blueprint $table): void {
                $table->unsignedBigInteger('active_user_id')->nullable();
                $table->unsignedBigInteger('default_user_id')->nullable();
                $table->unique('active_user_id', 'uq_biometric_active_user');
                $table->unique('default_user_id', 'uq_biometric_default_user');
            });
        }

        Schema::create('auth_sessions', function (Blueprint $table) {
            $this->configure($table);
            $table->id('auth_session_id');
            $table->binary('session_uuid', 16)->unique();
            $table->unsignedBigInteger('user_id')->nullable();
            $table->string('authentication_method', 20);
            $table->string('state', 20)->default('Active');
            $table->string('ip_address', 45);
            $table->string('user_agent', 512);
            $table->dateTime('issued_at')->useCurrent();
            $table->dateTime('last_activity_at')->useCurrent();
            $table->dateTime('expires_at');
            $table->dateTime('terminated_at')->nullable();
            $table->dateTime('revoked_at')->nullable();
            $table->dateTime('logged_out_at')->nullable();
            $table->string('terminal_reason', 30)->nullable();
            $table->dateTime('created_at')->useCurrent();
            $table->dateTime('updated_at')->useCurrent()->useCurrentOnUpdate();
            $table->foreign('user_id')->references('user_id')->on('user_profiles');
            $table->foreign('state')->references('state_code')->on('auth_session_state_lookups');
            $table->index(['user_id', 'state'], 'idx_auth_session_user_state');
            $table->index(['state', 'expires_at'], 'idx_auth_session_state_expiry');
            $table->index(['state', 'last_activity_at'], 'idx_auth_session_state_activity');
            $table->index(['state', 'terminated_at'], 'idx_auth_session_archival');
        });
        if (DB::getDriverName() === 'mysql') {
            DB::statement("
                ALTER TABLE auth_sessions
                ADD active_user_id BIGINT UNSIGNED
                    GENERATED ALWAYS AS (CASE WHEN state = 'Active' AND user_id IS NOT NULL THEN user_id ELSE NULL END) STORED,
                ADD UNIQUE KEY uq_auth_session_active_user (active_user_id)
            ");
        } else {
            Schema::table('auth_sessions', function (Blueprint $table): void {
                $table->unsignedBigInteger('active_user_id')->nullable();
                $table->unique('active_user_id', 'uq_auth_session_active_user');
            });
        }

        Schema::create('auth_session_archives', function (Blueprint $table) {
            $this->configure($table);
            $table->id('archive_id');
            $table->unsignedBigInteger('auth_session_id');
            $table->binary('session_uuid', 16)->unique();
            $table->unsignedBigInteger('user_id')->nullable();
            $table->string('authentication_method', 20);
            $table->string('state', 20);
            $table->string('ip_address', 45);
            $table->string('user_agent', 512);
            $table->dateTime('issued_at');
            $table->dateTime('last_activity_at');
            $table->dateTime('expires_at');
            $table->dateTime('terminated_at');
            $table->string('terminal_reason', 30)->nullable();
            $table->dateTime('archived_at')->useCurrent();
            $table->index(['user_id', 'terminated_at'], 'idx_session_archive_user_time');
            $table->index('terminated_at', 'idx_session_archive_terminated');
        });

        Schema::create('system_states', function (Blueprint $table) {
            $this->configure($table);
            $table->unsignedTinyInteger('system_state_id')->default(1)->primary();
            $table->unsignedTinyInteger('state_value');
            $table->unsignedSmallInteger('root_country_id');
            $table->unsignedBigInteger('activation_user_threshold')->default(44000000);
            $table->unsignedInteger('breathing_period_hours')->default(24);
            $table->dateTime('threshold_reached_at')->nullable();
            $table->dateTime('state_changed_at');
            $table->unsignedTinyInteger('changed_by_admin_id')->nullable();
            $table->dateTime('created_at')->useCurrent();
            $table->dateTime('updated_at')->useCurrent()->useCurrentOnUpdate();
            $table->foreign('state_value')->references('state_code')->on('system_state_lookups');
            $table->foreign('root_country_id')->references('country_id')->on('country_active_user_counters');
            $table->foreign('changed_by_admin_id')->references('admin_id')->on('system_admins');
            $table->index('state_value', 'idx_system_state_value');
        });

        if (DB::getDriverName() === 'mysql') {
            DB::statement("ALTER TABLE user_accounts
                ADD CONSTRAINT chk_user_account_status
                CHECK (account_status in ('Active','Locked','Closed'))");
            DB::statement("ALTER TABLE security_policies
                ADD CONSTRAINT chk_policy_max_failed CHECK (max_failed_attempts > 0),
                ADD CONSTRAINT chk_policy_base_lockout CHECK (base_lockout_seconds > 0),
                ADD CONSTRAINT chk_policy_progressive_factor CHECK (progressive_factor >= 1.0),
                ADD CONSTRAINT chk_policy_max_lockout CHECK (max_lockout_seconds >= base_lockout_seconds)");
            DB::statement("ALTER TABLE user_login_audit_logs
                ADD CONSTRAINT chk_login_audit_status CHECK (login_status in ('Success','Failed')),
                ADD CONSTRAINT chk_login_audit_failure CHECK (
                    (login_status = 'Success' and failure_reason is null)
                    or (login_status = 'Failed' and failure_reason is not null)
                )");
            DB::statement("ALTER TABLE system_states
                ADD CONSTRAINT chk_system_state_singleton CHECK (system_state_id = 1),
                ADD CONSTRAINT chk_system_state_value CHECK (state_value between 1 and 7)");
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('system_states');
        Schema::dropIfExists('auth_session_archives');
        Schema::dropIfExists('auth_sessions');
        Schema::dropIfExists('user_biometric_credentials');
        Schema::dropIfExists('user_login_audit_logs');
        Schema::dropIfExists('security_policies');
        Schema::dropIfExists('national_id_cooldown_ledgers');
        Schema::dropIfExists('user_geo_change_logs');
        Schema::dropIfExists('registration_drafts');
        Schema::dropIfExists('user_accounts');
        Schema::dropIfExists('user_profiles');
        Schema::dropIfExists('settlement_active_user_counters');
        Schema::dropIfExists('county_active_user_counters');
        Schema::dropIfExists('province_active_user_counters');
        Schema::dropIfExists('country_active_user_counters');
    }
};
