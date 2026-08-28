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

        $this->dropSettlementForeignKeys();

        DB::statement('ALTER TABLE settlements MODIFY settlement_id INT UNSIGNED NOT NULL AUTO_INCREMENT');

        $this->restoreSettlementForeignKeys();
    }

    public function down(): void
    {
        if (DB::getDriverName() !== 'mysql') {
            return;
        }

        $this->dropSettlementForeignKeys();

        DB::statement('ALTER TABLE settlements MODIFY settlement_id INT UNSIGNED NOT NULL');

        $this->restoreSettlementForeignKeys();
    }

    private function dropSettlementForeignKeys(): void
    {
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
    }

    private function restoreSettlementForeignKeys(): void
    {
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
