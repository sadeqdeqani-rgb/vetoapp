<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasColumn('registration_drafts', 'telegram_link_nonce_hash')) {
            Schema::table('registration_drafts', function (Blueprint $table) {
                $table->binary('telegram_link_nonce_hash', 32)->nullable()->after('settlement_id');
                $table->dateTime('telegram_link_nonce_expires_at')->nullable()->after('telegram_link_nonce_hash');
                $table->dateTime('telegram_link_nonce_used_at')->nullable()->after('telegram_link_nonce_expires_at');
                $table->dateTime('mobile_verified_at')->nullable()->after('telegram_link_nonce_used_at');
            });
        }
        if (! Schema::hasIndex('registration_drafts', 'idx_registration_draft_telegram_nonce')) {
            Schema::table('registration_drafts', function (Blueprint $table) {
                $table->index(
                    ['telegram_link_nonce_hash', 'telegram_link_nonce_used_at'],
                    'idx_registration_draft_telegram_nonce'
                );
            });
        }

        $this->dropProfileForeignKeys();
        DB::statement(
            'ALTER TABLE user_profiles MODIFY user_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT'
        );
        $this->restoreProfileForeignKeys();
    }

    public function down(): void
    {
        $this->dropProfileForeignKeys();
        DB::statement(
            'ALTER TABLE user_profiles MODIFY user_id BIGINT UNSIGNED NOT NULL'
        );
        $this->restoreProfileForeignKeys();

        Schema::table('registration_drafts', function (Blueprint $table) {
            $table->dropIndex('idx_registration_draft_telegram_nonce');
            $table->dropColumn([
                'telegram_link_nonce_hash',
                'telegram_link_nonce_expires_at',
                'telegram_link_nonce_used_at',
                'mobile_verified_at',
            ]);
        });
    }

    private function dropProfileForeignKeys(): void
    {
        foreach ([
            'auth_sessions',
            'user_accounts',
            'user_biometric_credentials',
            'user_geo_change_logs',
            'user_telegram_identities',
        ] as $tableName) {
            Schema::table($tableName, function (Blueprint $table) {
                $table->dropForeign(['user_id']);
            });
        }
    }

    private function restoreProfileForeignKeys(): void
    {
        Schema::table('auth_sessions', function (Blueprint $table) {
            $table->foreign('user_id')->references('user_id')->on('user_profiles');
        });
        Schema::table('user_accounts', function (Blueprint $table) {
            $table->foreign('user_id')->references('user_id')->on('user_profiles');
        });
        Schema::table('user_biometric_credentials', function (Blueprint $table) {
            $table->foreign('user_id')->references('user_id')->on('user_profiles');
        });
        Schema::table('user_geo_change_logs', function (Blueprint $table) {
            $table->foreign('user_id')->references('user_id')->on('user_profiles');
        });
        Schema::table('user_telegram_identities', function (Blueprint $table) {
            $table->foreign('user_id')->references('user_id')->on('user_profiles');
        });
    }
};
