<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('election_candidates')) Schema::create('election_candidates', function (Blueprint $table): void {
            $table->engine = 'InnoDB';
            $table->charset = 'utf8mb4';
            $table->collation = 'utf8mb4_0900_ai_ci';
            $table->bigIncrements('election_candidate_id');
            $table->unsignedBigInteger('process_id');
            $table->binary('normalized_identity_hash', 32, true);
            $table->string('normalized_given_name', 100);
            $table->string('normalized_family_name', 120);
            $table->string('normalized_father_name', 100);
            $table->string('display_given_name', 100);
            $table->string('display_family_name', 120);
            $table->string('display_father_name', 100);
            $table->dateTime('created_at', 3);
            $table->foreign('process_id')->references('process_id')->on('processes')->restrictOnDelete()->restrictOnUpdate();
            $table->unique(['process_id', 'normalized_identity_hash'], 'uq_election_candidate_identity');
            $table->unique(['process_id', 'election_candidate_id'], 'uq_election_candidate_process_id');
            $table->index(['process_id', 'created_at'], 'idx_election_candidate_created');
        });

        if (! Schema::hasTable('election_candidate_name_variants')) Schema::create('election_candidate_name_variants', function (Blueprint $table): void {
            $table->engine = 'InnoDB';
            $table->charset = 'utf8mb4';
            $table->collation = 'utf8mb4_0900_ai_ci';
            $table->bigIncrements('election_candidate_name_variant_id');
            $table->unsignedBigInteger('process_id');
            $table->unsignedBigInteger('election_candidate_id');
            $table->string('given_name', 100);
            $table->string('family_name', 120);
            $table->string('father_name', 100);
            $table->binary('variant_hash', 32, true);
            $table->dateTime('created_at', 3);
            $table->foreign(['process_id', 'election_candidate_id'], 'fk_candidate_variant_same_process')
                ->references(['process_id', 'election_candidate_id'])->on('election_candidates')->restrictOnDelete()->restrictOnUpdate();
            $table->unique(['process_id', 'variant_hash'], 'uq_election_candidate_variant');
            $table->index(['election_candidate_id', 'created_at'], 'idx_candidate_variant_candidate');
        });

        if (! Schema::hasColumn('process_ballot_options', 'election_candidate_id')) {
            Schema::table('process_ballot_options', function (Blueprint $table): void {
                $table->unsignedBigInteger('election_candidate_id')->nullable()->after('option_type_code');
                $table->foreign(['process_id', 'election_candidate_id'], 'fk_election_option_candidate_same_process')
                    ->references(['process_id', 'election_candidate_id'])->on('election_candidates')->restrictOnDelete()->restrictOnUpdate();
                $table->unique(['process_id', 'election_candidate_id'], 'uq_election_process_candidate_option');
            });
        }

        if (! Schema::hasColumn('ballot_box_entries', 'election_candidate_id')) {
            Schema::table('ballot_box_entries', function (Blueprint $table): void {
                $table->unsignedBigInteger('election_candidate_id')->nullable()->after('ballot_option_key');
                $table->foreign(['process_id', 'election_candidate_id'], 'fk_ballot_election_candidate_same_process')
                    ->references(['process_id', 'election_candidate_id'])->on('election_candidates')->restrictOnDelete()->restrictOnUpdate();
                $table->index(['process_id', 'election_candidate_id', 'sequence_no'], 'idx_ballot_election_candidate');
            });
        }

        if (! Schema::hasColumn('digital_receipt_vote_details', 'election_candidate_id')) {
            Schema::table('digital_receipt_vote_details', function (Blueprint $table): void {
                $table->unsignedBigInteger('election_candidate_id')->nullable()->after('ballot_box_entry_id');
                $table->string('candidate_given_name_snapshot', 100)->nullable();
                $table->string('candidate_family_name_snapshot', 120)->nullable();
                $table->string('candidate_father_name_snapshot', 100)->nullable();
                $table->foreign('election_candidate_id')->references('election_candidate_id')->on('election_candidates')->restrictOnDelete()->restrictOnUpdate();
                $table->index('election_candidate_id', 'idx_vote_receipt_candidate');
            });
        }

        if (DB::getDriverName() === 'mysql') {
            foreach ([
                'tr_electioncandidates_no_update', 'tr_electioncandidates_no_delete',
                'tr_electioncandidatenamevariants_no_update', 'tr_electioncandidatenamevariants_no_delete',
                'tr_ballotoptions_freeze_insert',
            ] as $trigger) {
                DB::unprepared("DROP TRIGGER IF EXISTS `{$trigger}`");
            }
        }

        // Candidate and option writes are restricted by ElectionVotingController.
        // Do not create MySQL triggers here: production binary logging prevents the
        // application database user from creating them without SUPER privileges.
    }

    public function down(): void
    {
        // No triggers are installed by this migration.
        Schema::table('digital_receipt_vote_details', function (Blueprint $table): void {
            $table->dropForeign('digital_receipt_vote_details_election_candidate_id_foreign');
            $table->dropIndex('idx_vote_receipt_candidate');
            $table->dropColumn(['election_candidate_id', 'candidate_given_name_snapshot', 'candidate_family_name_snapshot', 'candidate_father_name_snapshot']);
        });
        Schema::table('ballot_box_entries', function (Blueprint $table): void {
            $table->dropForeign('fk_ballot_election_candidate_same_process');
            $table->dropIndex('idx_ballot_election_candidate');
            $table->dropColumn('election_candidate_id');
        });
        Schema::table('process_ballot_options', function (Blueprint $table): void {
            $table->dropForeign('fk_election_option_candidate_same_process');
            $table->dropUnique('uq_election_process_candidate_option');
            $table->dropColumn('election_candidate_id');
        });
        Schema::dropIfExists('election_candidate_name_variants');
        Schema::dropIfExists('election_candidates');
    }
};
