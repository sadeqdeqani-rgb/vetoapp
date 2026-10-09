<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (DB::getDriverName() === 'mysql') {
            DB::statement(<<<'SQL'
                ALTER TABLE user_profiles
                    DROP INDEX user_profiles_mobile_hash_unique,
                    DROP INDEX user_profiles_national_id_hash_unique,
                    ADD COLUMN active_mobile_hash BINARY(32)
                        GENERATED ALWAYS AS (CASE WHEN is_active = 1 THEN mobile_hash ELSE NULL END) STORED,
                    ADD COLUMN active_national_id_hash BINARY(32)
                        GENERATED ALWAYS AS (CASE WHEN is_active = 1 THEN national_id_hash ELSE NULL END) STORED,
                    ADD UNIQUE KEY uq_user_profiles_active_mobile (active_mobile_hash),
                    ADD UNIQUE KEY uq_user_profiles_active_national_id (active_national_id_hash)
            SQL);

            return;
        }

        Schema::table('user_profiles', function (Blueprint $table): void {
            $table->dropUnique('user_profiles_mobile_hash_unique');
            $table->dropUnique('user_profiles_national_id_hash_unique');
            $table->binary('active_mobile_hash', 32)->nullable()
                ->storedAs('CASE WHEN is_active = 1 THEN mobile_hash ELSE NULL END');
            $table->binary('active_national_id_hash', 32)->nullable()
                ->storedAs('CASE WHEN is_active = 1 THEN national_id_hash ELSE NULL END');
            $table->unique('active_mobile_hash', 'uq_user_profiles_active_mobile');
            $table->unique('active_national_id_hash', 'uq_user_profiles_active_national_id');
        });
    }

    public function down(): void
    {
        if (DB::getDriverName() === 'mysql') {
            DB::statement(<<<'SQL'
                ALTER TABLE user_profiles
                    DROP INDEX uq_user_profiles_active_mobile,
                    DROP INDEX uq_user_profiles_active_national_id,
                    DROP COLUMN active_mobile_hash,
                    DROP COLUMN active_national_id_hash,
                    ADD UNIQUE KEY user_profiles_mobile_hash_unique (mobile_hash),
                    ADD UNIQUE KEY user_profiles_national_id_hash_unique (national_id_hash)
            SQL);

            return;
        }

        Schema::table('user_profiles', function (Blueprint $table): void {
            $table->dropUnique('uq_user_profiles_active_mobile');
            $table->dropUnique('uq_user_profiles_active_national_id');
            $table->dropColumn(['active_mobile_hash', 'active_national_id_hash']);
            $table->unique('mobile_hash', 'user_profiles_mobile_hash_unique');
            $table->unique('national_id_hash', 'user_profiles_national_id_hash_unique');
        });
    }
};
