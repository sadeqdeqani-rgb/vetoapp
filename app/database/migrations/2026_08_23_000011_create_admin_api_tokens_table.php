<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('admin_api_tokens', function (Blueprint $table): void {
            $table->engine = 'InnoDB';
            $table->charset = 'utf8mb4';
            $table->collation = 'utf8mb4_0900_ai_ci';
            $table->id('token_id');
            $table->unsignedTinyInteger('admin_id');
            $table->binary('token_hash', 32)->unique();
            $table->dateTime('expires_at');
            $table->dateTime('last_used_at')->nullable();
            $table->dateTime('revoked_at')->nullable();
            $table->dateTime('created_at')->useCurrent();

            $table->foreign('admin_id')
                ->references('admin_id')
                ->on('system_admins')
                ->restrictOnDelete()
                ->restrictOnUpdate();
            $table->index(['admin_id', 'revoked_at', 'expires_at'], 'idx_admin_token_validity');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('admin_api_tokens');
    }
};
