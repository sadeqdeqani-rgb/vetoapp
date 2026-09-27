<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('national_id_age_eligibility_reports', function (Blueprint $table): void {
            $table->engine = 'InnoDB';
            $table->charset = 'utf8mb4';
            $table->collation = 'utf8mb4_0900_ai_ci';
            $table->id('report_id');
            $table->unsignedBigInteger('registration_draft_id');
            $table->binary('national_id_hash', 32);
            $table->binary('national_id_encrypted', 255);
            $table->binary('birth_date_encrypted', 255);
            $table->string('status_code', 20)->default('Pending');
            $table->text('admin_note')->nullable();
            $table->dateTime('created_at')->useCurrent();
            $table->dateTime('updated_at')->useCurrent()->useCurrentOnUpdate();
            $table->foreign('registration_draft_id', 'fk_age_report_registration_draft')
                ->references('registration_draft_id')->on('registration_drafts');
            $table->index(['status_code', 'created_at'], 'idx_age_report_status_created');
            $table->index('national_id_hash', 'idx_age_report_national_id_hash');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('national_id_age_eligibility_reports');
    }
};
