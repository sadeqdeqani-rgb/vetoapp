<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('user_biometric_challenges', function (Blueprint $table): void {
            $table->engine = 'InnoDB';
            $table->charset = 'utf8mb4';
            $table->collation = 'utf8mb4_0900_ai_ci';
            $table->char('challenge_id', 36)->primary();
            $table->unsignedBigInteger('user_id')->nullable();
            $table->binary('credential_id', 255)->nullable();
            $table->string('purpose', 10);
            $table->binary('challenge', 32);
            $table->dateTime('expires_at');
            $table->dateTime('consumed_at')->nullable();
            $table->dateTime('created_at')->useCurrent();
            $table->foreign('user_id')->references('user_id')->on('user_profiles')->nullOnDelete();
            $table->index(['purpose', 'expires_at'], 'idx_biometric_challenge_expiry');
            $table->index(['user_id', 'created_at'], 'idx_biometric_challenge_user');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('user_biometric_challenges');
    }
};
