<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    private const BUCKETS = 64;

    public function up(): void
    {
        Schema::create('activation_request_counters', function (Blueprint $table): void {
            $table->unsignedTinyInteger('counter_bucket')->primary();
            $table->unsignedBigInteger('request_count')->default(0);
            $table->timestamp('updated_at')->nullable();
        });

        $rows = [];
        for ($bucket = 0; $bucket < self::BUCKETS; $bucket++) {
            $rows[] = [
                'counter_bucket' => $bucket,
                'request_count' => 0,
                'updated_at' => now(),
            ];
        }

        // One-time reconciliation from the authoritative request table.
        $rows[0]['request_count'] = DB::table('activation_client_requests')->count();
        DB::table('activation_request_counters')->insert($rows);
    }

    public function down(): void
    {
        Schema::dropIfExists('activation_request_counters');
    }
};
