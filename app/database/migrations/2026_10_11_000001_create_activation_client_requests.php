<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('activation_client_requests', function (Blueprint $table): void {
            $table->bigIncrements('activation_client_request_id');
            $table->string('platform_code', 16);
            // HMAC of the platform-scoped identifier; never store the raw ID/token.
            $table->char('device_key_hash', 64)->unique();
            $table->timestamp('requested_at')->useCurrent();
            $table->index(['platform_code', 'requested_at'], 'activation_client_requests_platform_time_idx');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('activation_client_requests');
    }
};
