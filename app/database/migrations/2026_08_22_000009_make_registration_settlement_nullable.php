<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('registration_drafts', function (Blueprint $table) {
            $table->unsignedInteger('settlement_id')->nullable()->change();
        });
    }

    public function down(): void
    {
        Schema::table('registration_drafts', function (Blueprint $table) {
            $table->unsignedInteger('settlement_id')->nullable(false)->change();
        });
    }
};
