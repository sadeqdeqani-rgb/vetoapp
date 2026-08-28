<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (DB::getDriverName() !== 'mysql') {
            return;
        }

        Schema::table('settlement_active_user_counters', function (Blueprint $table) {
            $table->dropForeign(['settlement_id']);
        });
        Schema::table('user_profiles', function (Blueprint $table) {
            $table->dropForeign(['settlement_id']);
        });
        Schema::table('registration_drafts', function (Blueprint $table) {
            $table->dropForeign(['settlement_id']);
        });
        Schema::table('user_geo_change_logs', function (Blueprint $table) {
            $table->dropForeign(['old_settlement_id']);
            $table->dropForeign(['new_settlement_id']);
        });

        foreach ([
            'settlement_active_user_counters' => ['settlement_id'],
            'user_profiles' => ['settlement_id'],
            'registration_drafts' => ['settlement_id'],
            'user_geo_change_logs' => ['old_settlement_id', 'new_settlement_id'],
        ] as $tableName => $columns) {
            Schema::table($tableName, function (Blueprint $table) use ($columns) {
                foreach ($columns as $column) {
                    $table->unsignedInteger($column)->change();
                }
            });
        }

        Schema::table('settlements', function (Blueprint $table) {
            $table->unsignedInteger('settlement_id')->change();
            $table->unsignedInteger('settlement_code')->change();
        });
        DB::statement('ALTER TABLE settlements MODIFY settlement_id INT UNSIGNED NOT NULL AUTO_INCREMENT');

        Schema::table('settlement_active_user_counters', function (Blueprint $table) {
            $table->foreign('settlement_id')->references('settlement_id')->on('settlements');
        });
        Schema::table('user_profiles', function (Blueprint $table) {
            $table->foreign('settlement_id')->references('settlement_id')->on('settlements');
        });
        Schema::table('registration_drafts', function (Blueprint $table) {
            $table->foreign('settlement_id')->references('settlement_id')->on('settlements');
        });
        Schema::table('user_geo_change_logs', function (Blueprint $table) {
            $table->foreign('old_settlement_id')->references('settlement_id')->on('settlements');
            $table->foreign('new_settlement_id')->references('settlement_id')->on('settlements');
        });
    }

    public function down(): void
    {
        if (DB::getDriverName() !== 'mysql') {
            return;
        }

        Schema::table('settlement_active_user_counters', function (Blueprint $table) {
            $table->dropForeign(['settlement_id']);
        });
        Schema::table('user_profiles', function (Blueprint $table) {
            $table->dropForeign(['settlement_id']);
        });
        Schema::table('registration_drafts', function (Blueprint $table) {
            $table->dropForeign(['settlement_id']);
        });
        Schema::table('user_geo_change_logs', function (Blueprint $table) {
            $table->dropForeign(['old_settlement_id']);
            $table->dropForeign(['new_settlement_id']);
        });

        foreach ([
            'user_geo_change_logs' => ['old_settlement_id', 'new_settlement_id'],
            'registration_drafts' => ['settlement_id'],
            'user_profiles' => ['settlement_id'],
            'settlement_active_user_counters' => ['settlement_id'],
        ] as $tableName => $columns) {
            Schema::table($tableName, function (Blueprint $table) use ($columns) {
                foreach ($columns as $column) {
                    $table->unsignedSmallInteger($column)->change();
                }
            });
        }

        Schema::table('settlements', function (Blueprint $table) {
            $table->unsignedSmallInteger('settlement_id')->change();
            $table->unsignedSmallInteger('settlement_code')->change();
        });
        DB::statement('ALTER TABLE settlements MODIFY settlement_id SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT');

        Schema::table('settlement_active_user_counters', function (Blueprint $table) {
            $table->foreign('settlement_id')->references('settlement_id')->on('settlements');
        });
        Schema::table('user_profiles', function (Blueprint $table) {
            $table->foreign('settlement_id')->references('settlement_id')->on('settlements');
        });
        Schema::table('registration_drafts', function (Blueprint $table) {
            $table->foreign('settlement_id')->references('settlement_id')->on('settlements');
        });
        Schema::table('user_geo_change_logs', function (Blueprint $table) {
            $table->foreign('old_settlement_id')->references('settlement_id')->on('settlements');
            $table->foreign('new_settlement_id')->references('settlement_id')->on('settlements');
        });
    }
};
