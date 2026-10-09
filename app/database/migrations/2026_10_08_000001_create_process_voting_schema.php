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
        $this->createLookups();
        $this->createProcessCore();
        $this->createBallotAndOutboxTables();
        $this->createParticipationAndReceiptTables();
        $this->createVotingLedger();
        $this->createPublicationTables();
        $this->createNotificationTables();
        $this->addChecks();
        $this->addAppendOnlyGuards();
    }

    private function createLookups(): void
    {
        Schema::create('process_state_lookups', function (Blueprint $table): void {
            $this->configure($table);
            $table->string('state_code', 50)->primary();
            $table->string('state_title', 100);
            $table->boolean('is_terminal');
            $table->boolean('is_active')->default(true);
            $table->unsignedInteger('display_order');
            $table->dateTime('created_at')->useCurrent();
            $table->dateTime('updated_at')->useCurrent()->useCurrentOnUpdate();
            $table->index(['is_active', 'display_order'], 'idx_process_state_active_order');
            $table->index('is_terminal', 'idx_process_state_terminal');
        });

        Schema::create('process_type_lookups', function (Blueprint $table): void {
            $this->configure($table);
            $table->string('process_type_code', 50)->primary();
            $table->string('title', 100)->unique('uq_process_type_title');
            $table->boolean('is_active')->default(true);
            $table->dateTime('created_at')->useCurrent();
            $table->dateTime('updated_at')->useCurrent()->useCurrentOnUpdate();
            $table->index('is_active', 'idx_process_type_active');
        });

        Schema::create('support_threshold_policy_lookups', function (Blueprint $table): void {
            $this->configure($table);
            $table->string('support_threshold_policy_code', 50)->primary();
            $table->string('policy_name', 120);
            $table->unsignedInteger('threshold_rate_ppm');
            $table->string('rounding_mode_code', 30)->default('CEIL');
            $table->unsignedBigInteger('min_support_count')->default(0);
            $table->boolean('is_active')->default(true);
            $table->dateTime('created_at')->useCurrent();
            $table->dateTime('updated_at')->useCurrent()->useCurrentOnUpdate();
            $table->index('is_active', 'idx_support_threshold_active');
        });

        Schema::create('vote_token_state_lookups', function (Blueprint $table): void {
            $this->configure($table);
            $table->string('token_state_code', 20)->primary();
            $table->string('title', 100);
            $table->boolean('is_terminal');
            $table->dateTime('created_at')->useCurrent();
        });

        // DRM V43 references a receipt type FK but does not number its lookup entity.
        // Keep the controlled vocabulary explicit instead of relying on free text.
        Schema::create('receipt_type_lookups', function (Blueprint $table): void {
            $this->configure($table);
            $table->string('receipt_type_code', 30)->primary();
            $table->string('title', 100);
            $table->boolean('is_active')->default(true);
            $table->dateTime('created_at')->useCurrent();
        });

        Schema::create('process_transition_rules', function (Blueprint $table): void {
            $this->configure($table);
            $table->id('process_transition_rule_id');
            $table->string('process_type_code', 50);
            $table->string('from_state_code', 50);
            $table->string('to_state_code', 50);
            $table->string('event_code', 60);
            $table->unsignedSmallInteger('rule_version');
            $table->boolean('requires_support_threshold')->default(false);
            $table->string('support_threshold_policy_code', 50)->nullable();
            $table->boolean('is_active')->default(true);
            $table->unsignedTinyInteger('active_rule_marker')->nullable();
            $table->dateTime('effective_from');
            $table->dateTime('effective_to')->nullable();
            $table->dateTime('created_at')->useCurrent();
            $table->dateTime('updated_at')->useCurrent()->useCurrentOnUpdate();
            $table->foreign('process_type_code')->references('process_type_code')->on('process_type_lookups')->restrictOnDelete()->restrictOnUpdate();
            $table->foreign('from_state_code')->references('state_code')->on('process_state_lookups')->restrictOnDelete()->restrictOnUpdate();
            $table->foreign('to_state_code')->references('state_code')->on('process_state_lookups')->restrictOnDelete()->restrictOnUpdate();
            $table->foreign('support_threshold_policy_code')->references('support_threshold_policy_code')->on('support_threshold_policy_lookups')->restrictOnDelete()->restrictOnUpdate();
            $table->unique(['process_type_code', 'from_state_code', 'event_code', 'rule_version'], 'uq_process_transition_version');
            $table->index(['is_active', 'effective_from', 'effective_to'], 'idx_process_transition_effective');
        });
        if (DB::getDriverName() === 'mysql') {
            DB::statement("ALTER TABLE process_transition_rules
                MODIFY active_rule_marker TINYINT UNSIGNED
                    GENERATED ALWAYS AS (CASE WHEN is_active = 1 THEN 1 ELSE NULL END) STORED,
                ADD UNIQUE KEY uq_process_transition_active (process_type_code, from_state_code, event_code, active_rule_marker)");
        } else {
            Schema::table('process_transition_rules', function (Blueprint $table): void {
                $table->unique(['process_type_code', 'from_state_code', 'event_code', 'active_rule_marker'], 'uq_process_transition_active');
            });
        }
    }

    private function createProcessCore(): void
    {
        Schema::create('processes', function (Blueprint $table): void {
            $this->configure($table);
            $table->id('process_id');
            $table->string('process_type_code', 50);
            $table->unsignedTinyInteger('target_geographic_level_code');
            $table->unsignedBigInteger('target_geographic_id');
            $table->string('title', 255);
            $table->unsignedBigInteger('created_by_user_id');
            $table->dateTime('voting_opens_at');
            $table->dateTime('voting_closes_at');
            $table->string('ballot_schema_id', 80);
            $table->unsignedSmallInteger('ballot_schema_version');
            $table->unsignedSmallInteger('canonical_encoding_version')->default(1);
            $table->unsignedSmallInteger('vote_token_ttl_seconds')->default(300);
            $table->unsignedInteger('result_publication_interval_seconds')->default(600);
            $table->dateTime('created_at')->useCurrent();
            $table->dateTime('updated_at')->useCurrent()->useCurrentOnUpdate();
            $table->foreign('process_type_code')->references('process_type_code')->on('process_type_lookups')->restrictOnDelete()->restrictOnUpdate();
            $table->foreign('target_geographic_level_code')->references('geographic_level_code')->on('geographic_level_lookups')->restrictOnDelete()->restrictOnUpdate();
            $table->foreign('created_by_user_id')->references('user_id')->on('user_profiles')->restrictOnDelete()->restrictOnUpdate();
            $table->index('process_type_code', 'idx_process_type');
            $table->index(['target_geographic_level_code', 'target_geographic_id'], 'idx_process_target_geo');
            $table->index('created_by_user_id', 'idx_process_creator');
            $table->index(['voting_opens_at', 'voting_closes_at'], 'idx_process_voting_window');
        });

        Schema::create('process_states', function (Blueprint $table): void {
            $this->configure($table);
            $table->id('process_state_id');
            $table->unsignedBigInteger('process_id');
            $table->string('current_state_code', 50);
            $table->dateTime('current_state_started_at');
            $table->dateTime('current_state_completed_at')->nullable();
            $table->unsignedBigInteger('active_process_id')->nullable();
            $table->dateTime('created_at')->useCurrent();
            $table->dateTime('updated_at')->useCurrent()->useCurrentOnUpdate();
            $table->foreign('process_id')->references('process_id')->on('processes')->restrictOnDelete()->restrictOnUpdate();
            $table->foreign('current_state_code')->references('state_code')->on('process_state_lookups')->restrictOnDelete()->restrictOnUpdate();
            $table->index('process_id', 'idx_process_state_process');
            $table->index('current_state_code', 'idx_process_state_code');
            $table->index(['process_id', 'current_state_started_at'], 'idx_process_state_process_started');
        });
        if (DB::getDriverName() === 'mysql') {
            DB::statement("ALTER TABLE process_states
                MODIFY active_process_id BIGINT UNSIGNED
                    GENERATED ALWAYS AS (IF(current_state_completed_at IS NULL, process_id, NULL)) STORED,
                ADD UNIQUE KEY uq_process_state_active_process (active_process_id)");
        } else {
            Schema::table('process_states', function (Blueprint $table): void {
                $table->unique('active_process_id', 'uq_process_state_active_process');
            });
        }

        Schema::create('process_population_snapshots', function (Blueprint $table): void {
            $this->configure($table);
            $table->unsignedBigInteger('process_id')->primary();
            $table->unsignedBigInteger('frozen_population_total');
            $table->dateTime('captured_at')->useCurrent();
            $table->foreign('process_id')->references('process_id')->on('processes')->restrictOnDelete()->restrictOnUpdate();
        });

        DB::statement('CREATE VIEW process_list_view AS
            SELECT p.process_id, p.process_type_code, p.target_geographic_level_code,
                   p.target_geographic_id, p.title, p.voting_opens_at,
                   p.voting_closes_at, p.created_at, ps.current_state_code,
                   ps.current_state_started_at
            FROM processes p
            LEFT JOIN process_states ps
              ON ps.process_id = p.process_id AND ps.current_state_completed_at IS NULL');
    }

    private function createParticipationAndReceiptTables(): void
    {
        Schema::create('support_participations', function (Blueprint $table): void {
            $this->configure($table);
            $table->id('support_participation_id');
            $table->unsignedBigInteger('process_id');
            $table->string('process_type_code', 50);
            $table->binary('supporter_identity_key', 32, true);
            $table->binary('idempotency_key', 32, true)->unique('uq_support_idempotency');
            $table->dateTime('participated_at');
            $table->unsignedSmallInteger('country_id');
            $table->unsignedSmallInteger('province_id');
            $table->unsignedSmallInteger('county_id');
            $table->unsignedInteger('settlement_id');
            $table->foreign('process_id')->references('process_id')->on('processes')->restrictOnDelete()->restrictOnUpdate();
            $table->foreign('process_type_code')->references('process_type_code')->on('process_type_lookups')->restrictOnDelete()->restrictOnUpdate();
            $table->foreign('country_id')->references('country_id')->on('countries')->restrictOnDelete()->restrictOnUpdate();
            $table->foreign('province_id')->references('province_id')->on('provinces')->restrictOnDelete()->restrictOnUpdate();
            $table->foreign('county_id')->references('county_id')->on('counties')->restrictOnDelete()->restrictOnUpdate();
            $table->foreign('settlement_id')->references('settlement_id')->on('settlements')->restrictOnDelete()->restrictOnUpdate();
            $table->unique(['process_id', 'supporter_identity_key'], 'uq_support_once');
            $table->index(['process_id', 'participated_at'], 'idx_support_process_time');
            $table->index(['process_id', 'country_id', 'province_id', 'county_id', 'settlement_id'], 'idx_support_geo_hierarchy');
            $table->index(['process_type_code', 'process_id'], 'idx_support_type_process');
        });

        Schema::create('digital_receipts', function (Blueprint $table): void {
            $this->configure($table);
            $table->id('digital_receipt_id');
            $table->unsignedBigInteger('process_id');
            $table->unsignedBigInteger('beneficiary_user_account_id')->nullable();
            $table->binary('participant_identity_key', 32, true)->nullable();
            $table->binary('support_idempotency_key', 32, true)->nullable()->unique('uq_receipt_support_idempotency');
            $table->string('receipt_type_code', 30);
            $table->string('process_type_code', 50);
            $table->string('event_title_snapshot', 255);
            $table->binary('receipt_number', 32, true)->unique('uq_digital_receipt_number');
            $table->unsignedSmallInteger('payload_version');
            $table->binary('receipt_hash', 32, true);
            $table->binary('signature_value', 512);
            $table->string('key_id', 100);
            $table->dateTime('issued_at', 3);
            $table->foreign('process_id')->references('process_id')->on('processes')->restrictOnDelete()->restrictOnUpdate();
            $table->foreign('beneficiary_user_account_id')->references('user_id')->on('user_accounts')->restrictOnDelete()->restrictOnUpdate();
            $table->foreign('receipt_type_code')->references('receipt_type_code')->on('receipt_type_lookups')->restrictOnDelete()->restrictOnUpdate();
            $table->foreign('process_type_code')->references('process_type_code')->on('process_type_lookups')->restrictOnDelete()->restrictOnUpdate();
            $table->index(['process_id', 'issued_at'], 'idx_receipt_process_time');
            $table->index(['beneficiary_user_account_id', 'issued_at'], 'idx_receipt_account_time');
        });

        Schema::create('digital_receipt_support_details', function (Blueprint $table): void {
            $this->configure($table);
            $table->unsignedBigInteger('digital_receipt_id')->primary();
            $table->unsignedSmallInteger('support_payload_version')->default(1);
            $table->string('support_note_snapshot', 255)->nullable();
            $table->dateTime('created_at')->useCurrent();
            $table->foreign('digital_receipt_id')->references('digital_receipt_id')->on('digital_receipts')->restrictOnDelete()->restrictOnUpdate();
        });
    }

    private function createVotingLedger(): void
    {
        Schema::create('voter_participations', function (Blueprint $table): void {
            $this->configure($table);
            $table->id('voter_participation_id');
            $table->unsignedBigInteger('process_id');
            $table->binary('participant_identity_key', 32, true);
            $table->dateTime('participated_at', 3);
            $table->unsignedSmallInteger('country_id');
            $table->unsignedSmallInteger('province_id');
            $table->unsignedSmallInteger('county_id');
            $table->unsignedInteger('settlement_id');
            $table->foreign('process_id')->references('process_id')->on('processes')->restrictOnDelete()->restrictOnUpdate();
            $table->foreign('country_id')->references('country_id')->on('countries')->restrictOnDelete()->restrictOnUpdate();
            $table->foreign('province_id')->references('province_id')->on('provinces')->restrictOnDelete()->restrictOnUpdate();
            $table->foreign('county_id')->references('county_id')->on('counties')->restrictOnDelete()->restrictOnUpdate();
            $table->foreign('settlement_id')->references('settlement_id')->on('settlements')->restrictOnDelete()->restrictOnUpdate();
            $table->unique(['process_id', 'participant_identity_key'], 'uq_voter_participation_once');
            $table->index(['process_id', 'participated_at'], 'idx_voter_participation_time');
            $table->index(['process_id', 'country_id', 'province_id', 'county_id', 'settlement_id'], 'idx_voter_participation_geo');
        });

        Schema::create('vote_tokens', function (Blueprint $table): void {
            $this->configure($table);
            $table->id('vote_token_id');
            $table->unsignedBigInteger('process_id');
            $table->binary('participant_identity_key', 32, true);
            $table->binary('token_hash', 32, true)->unique('uq_vote_token_hash');
            $table->string('token_state_code', 20);
            $table->dateTime('issued_at', 6);
            $table->dateTime('expires_at', 6);
            $table->dateTime('consumed_at', 6)->nullable();
            $table->dateTime('revoked_at', 6)->nullable();
            $table->binary('issuance_idempotency_key', 32, true)->unique('uq_vote_token_issuance_key');
            $table->unsignedBigInteger('active_process_id')->nullable();
            $table->binary('active_identity_key', 32, true)->nullable();
            $table->foreign('process_id')->references('process_id')->on('processes')->restrictOnDelete()->restrictOnUpdate();
            $table->foreign('token_state_code')->references('token_state_code')->on('vote_token_state_lookups')->restrictOnDelete()->restrictOnUpdate();
            $table->index(['process_id', 'participant_identity_key'], 'idx_vote_token_identity_process');
            $table->index(['token_state_code', 'expires_at'], 'idx_vote_token_state_expiry');
        });
        if (DB::getDriverName() === 'mysql') {
            DB::statement("ALTER TABLE vote_tokens
                MODIFY active_process_id BIGINT UNSIGNED
                    GENERATED ALWAYS AS (CASE WHEN token_state_code = 'ISSUED' THEN process_id ELSE NULL END) STORED,
                MODIFY active_identity_key BINARY(32)
                    GENERATED ALWAYS AS (CASE WHEN token_state_code = 'ISSUED' THEN participant_identity_key ELSE NULL END) STORED,
                ADD UNIQUE KEY uq_vote_token_one_active (active_process_id, active_identity_key)");
        } else {
            Schema::table('vote_tokens', function (Blueprint $table): void {
                $table->unique(['active_process_id', 'active_identity_key'], 'uq_vote_token_one_active');
            });
        }

        Schema::create('ballot_box_entries', function (Blueprint $table): void {
            $this->configure($table);
            $table->id('ballot_box_entry_id');
            $table->unsignedBigInteger('process_id');
            $table->unsignedBigInteger('sequence_no');
            $table->binary('previous_hash', 32, true);
            $table->binary('current_hash', 32, true);
            $table->string('ballot_option_key', 80);
            $table->binary('canonical_vote_payload', 512);
            $table->binary('ballot_submission_idempotency_key', 32, true)->unique('uq_ballot_idempotency');
            $table->dateTime('recorded_at', 3);
            $table->unsignedSmallInteger('country_id');
            $table->unsignedSmallInteger('province_id');
            $table->unsignedSmallInteger('county_id');
            $table->unsignedInteger('settlement_id');
            $table->foreign('process_id')->references('process_id')->on('processes')->restrictOnDelete()->restrictOnUpdate();
            $table->foreign('country_id')->references('country_id')->on('countries')->restrictOnDelete()->restrictOnUpdate();
            $table->foreign('province_id')->references('province_id')->on('provinces')->restrictOnDelete()->restrictOnUpdate();
            $table->foreign('county_id')->references('county_id')->on('counties')->restrictOnDelete()->restrictOnUpdate();
            $table->foreign('settlement_id')->references('settlement_id')->on('settlements')->restrictOnDelete()->restrictOnUpdate();
            $table->foreign(['process_id', 'ballot_option_key'], 'fk_ballot_process_option')
                ->references(['process_id', 'option_key'])->on('process_ballot_options')->restrictOnDelete()->restrictOnUpdate();
            $table->unique(['process_id', 'sequence_no'], 'uq_ballot_process_sequence');
            $table->unique(['process_id', 'current_hash'], 'uq_ballot_process_hash');
            $table->index(['process_id', 'recorded_at'], 'idx_ballot_process_recorded');
        });
    }

    private function createPublicationTables(): void
    {
        Schema::create('digital_receipt_vote_details', function (Blueprint $table): void {
            $this->configure($table);
            $table->unsignedBigInteger('digital_receipt_id')->primary();
            $table->unsignedBigInteger('ballot_box_entry_id')->unique('uq_vote_receipt_ballot');
            $table->unsignedSmallInteger('vote_payload_version');
            $table->string('ballot_choice_key_snapshot', 80);
            $table->string('ballot_choice_label_snapshot', 255);
            $table->binary('ballot_commitment', 32, true);
            $table->dateTime('created_at', 3);
            $table->foreign('digital_receipt_id')->references('digital_receipt_id')->on('digital_receipts')->restrictOnDelete()->restrictOnUpdate();
            $table->foreign('ballot_box_entry_id')->references('ballot_box_entry_id')->on('ballot_box_entries')->restrictOnDelete()->restrictOnUpdate();
        });

        Schema::create('process_sequence_allocators', function (Blueprint $table): void {
            $this->configure($table);
            $table->unsignedBigInteger('process_id')->primary();
            $table->unsignedBigInteger('next_sequence_no');
            $table->binary('last_hash', 32, true);
            $table->string('hash_version', 50);
            $table->dateTime('last_appended_at', 6);
            $table->foreign('process_id')->references('process_id')->on('processes')->restrictOnDelete()->restrictOnUpdate();
        });

        Schema::create('process_chain_heads', function (Blueprint $table): void {
            $this->configure($table);
            $table->unsignedBigInteger('process_id')->primary();
            $table->unsignedBigInteger('last_sequence_no');
            $table->binary('last_hash', 32, true);
            $table->string('hash_version', 50);
            $table->dateTime('finalized_at', 6);
            $table->foreign('process_id')->references('process_id')->on('processes')->restrictOnDelete()->restrictOnUpdate();
        });

        Schema::create('process_merkle_trees', function (Blueprint $table): void {
            $this->configure($table);
            $table->id('merkle_tree_id');
            $table->unsignedBigInteger('process_id');
            $table->unsignedBigInteger('checkpoint_no');
            $table->unsignedBigInteger('previous_checkpoint_id')->nullable();
            $table->unsignedBigInteger('supersedes_checkpoint_id')->nullable();
            $table->string('correction_reason', 500)->nullable();
            $table->string('checkpoint_kind', 20);
            $table->binary('root_hash', 32, true);
            $table->string('tree_version', 50);
            $table->unsignedSmallInteger('canonical_encoding_version');
            $table->unsignedBigInteger('leaf_count');
            $table->unsignedBigInteger('last_sequence_no');
            $table->unsignedBigInteger('source_outbox_watermark');
            $table->binary('signature_value', 512);
            $table->string('signing_key_id', 100);
            $table->dateTime('generated_at', 6);
            $table->dateTime('published_at', 6);
            // MySQL adds Blueprint constraints and indexes as separate ALTERs
            // in declaration order. The self-referencing composite FKs need
            // this parent index to exist before those FK ALTERs are issued.
            $table->unique(['process_id', 'merkle_tree_id'], 'uq_merkle_process_tree_id');
            $table->foreign('process_id')->references('process_id')->on('processes')->restrictOnDelete()->restrictOnUpdate();
            $table->foreign(['process_id', 'previous_checkpoint_id'], 'fk_merkle_previous_same_process')
                ->references(['process_id', 'merkle_tree_id'])->on('process_merkle_trees')->restrictOnDelete()->restrictOnUpdate();
            $table->foreign(['process_id', 'supersedes_checkpoint_id'], 'fk_merkle_supersedes_same_process')
                ->references(['process_id', 'merkle_tree_id'])->on('process_merkle_trees')->restrictOnDelete()->restrictOnUpdate();
            $table->unique(['process_id', 'checkpoint_no'], 'uq_merkle_process_checkpoint');
            $table->index(['process_id', 'published_at'], 'idx_merkle_process_published');
            $table->index(['process_id', 'leaf_count'], 'idx_merkle_process_size');
        });

        Schema::create('process_geographic_counters', function (Blueprint $table): void {
            $this->configure($table);
            $table->id('process_geographic_counter_id');
            $table->unsignedBigInteger('process_id');
            $table->string('counter_type', 40);
            $table->unsignedTinyInteger('geographic_level_code');
            $table->unsignedBigInteger('geographic_id');
            $table->string('ballot_choice_key', 80)->default('ALL');
            $table->unsignedBigInteger('counter_value')->default(0);
            $table->dateTime('last_reconciled_at')->nullable();
            $table->foreign('process_id')->references('process_id')->on('processes')->restrictOnDelete()->restrictOnUpdate();
            $table->foreign('geographic_level_code')->references('geographic_level_code')->on('geographic_level_lookups')->restrictOnDelete()->restrictOnUpdate();
            $table->unique(['process_id', 'counter_type', 'geographic_level_code', 'geographic_id', 'ballot_choice_key'], 'uq_process_geo_counter_scope');
            $table->index(['process_id', 'counter_type'], 'idx_process_counter_type');
        });
    }

    private function createNotificationTables(): void
    {
        Schema::create('notifications', function (Blueprint $table): void {
            $this->configure($table);
            $table->id('notification_id');
            $table->unsignedBigInteger('process_id');
            $table->string('notification_type', 50);
            $table->string('audience_scope', 50);
            $table->string('source_entity_type', 50)->nullable();
            $table->unsignedBigInteger('source_entity_id')->nullable();
            $table->string('title_template_key', 100);
            $table->string('body_template_key', 100);
            $table->json('payload_snapshot')->nullable();
            $table->string('priority', 20)->default('NORMAL');
            $table->string('state', 30)->default('DRAFT');
            $table->dateTime('created_at')->useCurrent();
            $table->foreign('process_id')->references('process_id')->on('processes')->restrictOnDelete()->restrictOnUpdate();
            $table->index(['process_id', 'state', 'created_at'], 'idx_notification_process_state');
        });

        Schema::create('notification_dispatches', function (Blueprint $table): void {
            $this->configure($table);
            $table->id('notification_dispatch_id');
            $table->unsignedBigInteger('notification_id');
            $table->unsignedBigInteger('user_profile_id')->nullable();
            $table->string('channel_type', 50);
            $table->binary('idempotency_key', 32, true)->unique('uq_notification_dispatch_idempotency');
            $table->string('state', 30)->default('PENDING');
            $table->unsignedTinyInteger('attempt_count')->default(0);
            $table->string('last_error', 500)->nullable();
            $table->dateTime('sent_at')->nullable();
            $table->dateTime('created_at')->useCurrent();
            $table->foreign('notification_id')->references('notification_id')->on('notifications')->restrictOnDelete()->restrictOnUpdate();
            $table->foreign('user_profile_id')->references('user_id')->on('user_profiles')->restrictOnDelete()->restrictOnUpdate();
            $table->index(['notification_id', 'state'], 'idx_dispatch_notification_state');
            $table->index(['state', 'created_at'], 'idx_dispatch_state_created');
        });

        Schema::create('user_notifications', function (Blueprint $table): void {
            $this->configure($table);
            $table->id('user_notification_id');
            $table->unsignedBigInteger('user_profile_id');
            $table->unsignedBigInteger('notification_id');
            $table->boolean('is_archived')->default(false);
            $table->dateTime('read_at')->nullable();
            $table->dateTime('created_at')->useCurrent();
            $table->foreign('user_profile_id')->references('user_id')->on('user_profiles')->restrictOnDelete()->restrictOnUpdate();
            $table->foreign('notification_id')->references('notification_id')->on('notifications')->restrictOnDelete()->restrictOnUpdate();
            $table->unique(['user_profile_id', 'notification_id'], 'uq_user_notification_once');
            $table->index(['user_profile_id', 'read_at', 'created_at'], 'idx_user_notification_inbox');
            $table->index(['user_profile_id', 'created_at'], 'idx_user_notification_sort');
        });
    }

    private function createBallotAndOutboxTables(): void
    {
        Schema::create('process_ballot_options', function (Blueprint $table): void {
            $this->configure($table);
            $table->id('process_ballot_option_id');
            $table->unsignedBigInteger('process_id');
            $table->string('option_key', 80);
            $table->string('option_type_code', 30);
            $table->string('display_label', 255);
            $table->string('candidate_given_name', 100)->nullable();
            $table->string('candidate_family_name', 120)->nullable();
            $table->string('candidate_father_name', 100)->nullable();
            $table->boolean('is_active')->default(true);
            $table->dateTime('created_at')->useCurrent();
            $table->foreign('process_id')->references('process_id')->on('processes')->restrictOnDelete()->restrictOnUpdate();
            $table->unique(['process_id', 'option_key'], 'uq_process_ballot_option');
            $table->index(['process_id', 'is_active'], 'idx_ballot_option_active');
        });

        Schema::create('process_projection_outbox_events', function (Blueprint $table): void {
            $this->configure($table);
            $table->id('process_projection_outbox_event_id');
            $table->unsignedBigInteger('process_id');
            $table->string('event_type_code', 40);
            $table->unsignedBigInteger('source_record_id');
            $table->binary('event_key', 32, true)->unique('uq_process_outbox_event_key');
            $table->json('payload');
            $table->dateTime('created_at')->useCurrent();
            $table->dateTime('processed_at')->nullable();
            $table->unsignedSmallInteger('attempts')->default(0);
            $table->foreign('process_id')->references('process_id')->on('processes')->restrictOnDelete()->restrictOnUpdate();
            $table->unique(['event_type_code', 'source_record_id'], 'uq_process_outbox_source_event');
            $table->index(['processed_at', 'process_projection_outbox_event_id'], 'idx_process_outbox_pending');
            $table->index(['process_id', 'process_projection_outbox_event_id'], 'idx_process_outbox_watermark');
        });
    }

    private function addChecks(): void
    {
        if (DB::getDriverName() !== 'mysql') {
            return;
        }
        DB::statement("ALTER TABLE support_threshold_policy_lookups
            ADD CONSTRAINT chk_support_threshold_rate CHECK (threshold_rate_ppm BETWEEN 1 AND 1000000),
            ADD CONSTRAINT chk_support_threshold_rounding CHECK (rounding_mode_code = 'CEIL')");
        DB::statement("ALTER TABLE process_transition_rules
            ADD CONSTRAINT chk_transition_threshold_binding CHECK (
                (requires_support_threshold = 1 AND support_threshold_policy_code IS NOT NULL)
                OR (requires_support_threshold = 0 AND support_threshold_policy_code IS NULL)
            ),
            ADD CONSTRAINT chk_transition_effective_window CHECK (effective_to IS NULL OR effective_to > effective_from)");
        DB::statement("ALTER TABLE processes
            ADD CONSTRAINT chk_process_voting_window CHECK (voting_closes_at > voting_opens_at),
            ADD CONSTRAINT chk_process_vote_token_ttl CHECK (vote_token_ttl_seconds BETWEEN 120 AND 600),
            ADD CONSTRAINT chk_process_result_interval CHECK (result_publication_interval_seconds > 0)");
        DB::statement("ALTER TABLE process_states
            ADD CONSTRAINT chk_process_state_interval CHECK (
                current_state_completed_at IS NULL OR current_state_completed_at > current_state_started_at
            )");
        DB::statement("ALTER TABLE vote_tokens
            ADD CONSTRAINT chk_vote_token_expiry CHECK (expires_at > issued_at),
            ADD CONSTRAINT chk_vote_token_state_timestamps CHECK (
                (token_state_code = 'ISSUED' AND consumed_at IS NULL AND revoked_at IS NULL)
                OR (token_state_code = 'USED' AND consumed_at IS NOT NULL AND revoked_at IS NULL)
                OR (token_state_code = 'REVOKED' AND consumed_at IS NULL AND revoked_at IS NOT NULL)
                OR (token_state_code = 'EXPIRED' AND consumed_at IS NULL AND revoked_at IS NULL)
            )");
        DB::statement("ALTER TABLE ballot_box_entries
            ADD CONSTRAINT chk_ballot_sequence_positive CHECK (sequence_no > 0)");
        DB::statement("ALTER TABLE digital_receipts
            ADD CONSTRAINT chk_receipt_support_identity CHECK (
                (receipt_type_code = 'SUPPORT' AND beneficiary_user_account_id IS NOT NULL
                 AND participant_identity_key IS NOT NULL AND support_idempotency_key IS NOT NULL)
                OR (receipt_type_code = 'VOTE' AND beneficiary_user_account_id IS NULL
                    AND participant_identity_key IS NULL AND support_idempotency_key IS NULL)
            )");
        DB::statement("ALTER TABLE process_merkle_trees
            ADD CONSTRAINT chk_merkle_checkpoint_kind CHECK (checkpoint_kind IN ('PERIODIC', 'FINAL', 'CORRECTION')),
            ADD CONSTRAINT chk_merkle_correction_fields CHECK (
                (checkpoint_kind = 'CORRECTION' AND correction_reason IS NOT NULL AND supersedes_checkpoint_id IS NOT NULL)
                OR (checkpoint_kind <> 'CORRECTION' AND correction_reason IS NULL AND supersedes_checkpoint_id IS NULL)
            ),
            ADD CONSTRAINT chk_merkle_prefix_size CHECK (leaf_count = last_sequence_no)");
        DB::statement("ALTER TABLE process_projection_outbox_events
            ADD CONSTRAINT chk_process_outbox_event_type CHECK (event_type_code IN ('SUPPORT_COMMITTED', 'BALLOT_COMMITTED'))");
        DB::statement("ALTER TABLE notifications
            ADD CONSTRAINT chk_notification_source_pair CHECK (
                (source_entity_type IS NULL AND source_entity_id IS NULL)
                OR (source_entity_type IS NOT NULL AND source_entity_id IS NOT NULL)
            ),
            ADD CONSTRAINT chk_notification_state CHECK (state IN ('DRAFT', 'READY', 'CANCELLED'))");
        DB::statement("ALTER TABLE notification_dispatches
            ADD CONSTRAINT chk_notification_dispatch_state CHECK (state IN ('PENDING', 'SENT', 'FAILED', 'RETRYING'))");
    }

    private function addAppendOnlyGuards(): void
    {
        if (DB::getDriverName() !== 'mysql') {
            return;
        }

        foreach ([
            'process_population_snapshots',
            'support_participations',
            'voter_participations',
            'digital_receipts',
            'digital_receipt_support_details',
            'digital_receipt_vote_details',
            'ballot_box_entries',
            'process_chain_heads',
            'process_merkle_trees',
        ] as $table) {
            $name = str_replace('_', '', $table);
            DB::unprepared("CREATE TRIGGER tr_{$name}_no_update BEFORE UPDATE ON {$table}
                FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Append-only VetoApp records cannot be updated'");
            DB::unprepared("CREATE TRIGGER tr_{$name}_no_delete BEFORE DELETE ON {$table}
                FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Append-only VetoApp records cannot be deleted'");
        }

        DB::unprepared("CREATE TRIGGER tr_processoutboxevents_immutable_fields BEFORE UPDATE ON process_projection_outbox_events
            FOR EACH ROW
            BEGIN
                IF NOT (NEW.process_id <=> OLD.process_id)
                    OR NOT (NEW.event_type_code <=> OLD.event_type_code)
                    OR NOT (NEW.source_record_id <=> OLD.source_record_id)
                    OR NOT (NEW.event_key <=> OLD.event_key)
                    OR NOT (NEW.payload <=> OLD.payload)
                    OR NOT (NEW.created_at <=> OLD.created_at) THEN
                    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Outbox event source fields are immutable';
                END IF;
            END");
        DB::unprepared("CREATE TRIGGER tr_processoutboxevents_no_delete BEFORE DELETE ON process_projection_outbox_events
            FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Outbox events cannot be deleted'");

        DB::unprepared("CREATE TRIGGER tr_processes_freeze_voting_contract BEFORE UPDATE ON processes
            FOR EACH ROW
            BEGIN
                IF EXISTS (SELECT 1 FROM process_states WHERE process_id = OLD.process_id AND current_state_code = 'VoteCasting')
                    AND (
                        NOT (NEW.process_type_code <=> OLD.process_type_code)
                        OR NOT (NEW.target_geographic_level_code <=> OLD.target_geographic_level_code)
                        OR NOT (NEW.target_geographic_id <=> OLD.target_geographic_id)
                        OR NOT (NEW.ballot_schema_id <=> OLD.ballot_schema_id)
                        OR NOT (NEW.ballot_schema_version <=> OLD.ballot_schema_version)
                        OR NOT (NEW.canonical_encoding_version <=> OLD.canonical_encoding_version)
                        OR NOT (NEW.voting_opens_at <=> OLD.voting_opens_at)
                        OR NOT (NEW.voting_closes_at <=> OLD.voting_closes_at)
                    ) THEN
                    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Voting contract is frozen after VoteCasting begins';
                END IF;
            END");
        DB::unprepared('CREATE TRIGGER tr_processes_no_delete BEFORE DELETE ON processes
            FOR EACH ROW SIGNAL SQLSTATE \'45000\' SET MESSAGE_TEXT = \'Process records are retained\'');

        DB::unprepared("CREATE TRIGGER tr_ballotoptions_freeze_insert BEFORE INSERT ON process_ballot_options
            FOR EACH ROW
            BEGIN
                IF EXISTS (SELECT 1 FROM process_states WHERE process_id = NEW.process_id AND current_state_code = 'VoteCasting') THEN
                    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ballot options are frozen after VoteCasting begins';
                END IF;
            END");
        DB::unprepared("CREATE TRIGGER tr_ballotoptions_freeze_update BEFORE UPDATE ON process_ballot_options
            FOR EACH ROW
            BEGIN
                IF EXISTS (SELECT 1 FROM process_states WHERE process_id = OLD.process_id AND current_state_code = 'VoteCasting') THEN
                    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ballot options are frozen after VoteCasting begins';
                END IF;
            END");
        DB::unprepared("CREATE TRIGGER tr_ballotoptions_freeze_delete BEFORE DELETE ON process_ballot_options
            FOR EACH ROW
            BEGIN
                IF EXISTS (SELECT 1 FROM process_states WHERE process_id = OLD.process_id AND current_state_code = 'VoteCasting') THEN
                    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ballot options are frozen after VoteCasting begins';
                END IF;
            END");
    }

    public function down(): void
    {
        if (DB::getDriverName() === 'mysql') {
            foreach ([
                'processpopulationsnapshots', 'supportparticipations', 'voterparticipations',
                'digitalreceipts', 'digitalreceiptsupportdetails', 'digitalreceiptvotedetails',
                'ballotboxentries', 'processchainheads', 'processmerkletrees',
            ] as $name) {
                DB::unprepared("DROP TRIGGER IF EXISTS tr_{$name}_no_update");
                DB::unprepared("DROP TRIGGER IF EXISTS tr_{$name}_no_delete");
            }
            DB::unprepared('DROP TRIGGER IF EXISTS tr_processoutboxevents_immutable_fields');
            DB::unprepared('DROP TRIGGER IF EXISTS tr_processoutboxevents_no_delete');
            DB::unprepared('DROP TRIGGER IF EXISTS tr_processes_freeze_voting_contract');
            DB::unprepared('DROP TRIGGER IF EXISTS tr_processes_no_delete');
            DB::unprepared('DROP TRIGGER IF EXISTS tr_ballotoptions_freeze_insert');
            DB::unprepared('DROP TRIGGER IF EXISTS tr_ballotoptions_freeze_update');
            DB::unprepared('DROP TRIGGER IF EXISTS tr_ballotoptions_freeze_delete');
        }
        DB::statement('DROP VIEW IF EXISTS process_list_view');
        foreach ([
            'process_projection_outbox_events', 'user_notifications', 'notification_dispatches',
            'notifications', 'digital_receipt_vote_details', 'digital_receipt_support_details',
            'process_merkle_trees', 'process_geographic_counters', 'process_chain_heads',
            'process_sequence_allocators', 'ballot_box_entries', 'vote_tokens',
            'voter_participations', 'digital_receipts', 'support_participations',
            'process_ballot_options', 'process_population_snapshots', 'process_states', 'processes',
            'process_transition_rules', 'receipt_type_lookups', 'vote_token_state_lookups',
            'support_threshold_policy_lookups', 'process_type_lookups', 'process_state_lookups',
        ] as $table) {
            Schema::dropIfExists($table);
        }
    }
};
