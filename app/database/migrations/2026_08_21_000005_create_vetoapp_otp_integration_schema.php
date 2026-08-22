<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    private function configure(Blueprint $table): void
    {
        $table->engine = 'InnoDB';
        $table->charset = 'utf8mb4';
        $table->collation = 'utf8mb4_0900_ai_ci';
    }

    public function up(): void
    {
        Schema::create('otp_throttle_windows', function (Blueprint $table) {
            $this->configure($table);
            $table->id('otp_throttle_window_id');
            $table->binary('mobile_hash', 32);
            $table->binary('mobile_encrypted', 255);
            $table->dateTime('window_started_at');
            $table->dateTime('window_ends_at');
            $table->unsignedTinyInteger('send_count')->default(0);
            $table->unsignedTinyInteger('verify_failed_count')->default(0);
            $table->string('state', 15);
            $table->unsignedTinyInteger('penalty_tier')->default(0);
            $table->dateTime('last_sent_at')->nullable();
            $table->dateTime('throttled_until')->nullable();
            $table->dateTime('blocked_until')->nullable();
            $table->dateTime('created_at')->useCurrent();
            $table->dateTime('updated_at')->useCurrent()->useCurrentOnUpdate();
            $table->foreign('state')->references('state_code')->on('otp_throttle_window_state_lookups');
            $table->index(['mobile_hash', 'state'], 'idx_otp_throttle_mobile_state');
            $table->index(['throttled_until', 'blocked_until'], 'idx_otp_throttle_until');
            $table->index('window_ends_at', 'idx_otp_throttle_window_end');
        });

        Schema::create('otps', function (Blueprint $table) {
            $this->configure($table);
            $table->id('otp_id');
            $table->binary('mobile_hash', 32);
            $table->binary('mobile_encrypted', 255);
            $table->string('purpose', 25);
            $table->binary('otp_nonce', 16);
            $table->binary('code_hash', 32);
            $table->string('state', 15)->default('Issued');
            $table->dateTime('issued_at');
            $table->dateTime('expires_at');
            $table->dateTime('verified_at')->nullable();
            $table->dateTime('failed_at')->nullable();
            $table->unsignedTinyInteger('attempt_count')->default(0);
            $table->unsignedTinyInteger('max_attempt_count')->default(3);
            $table->string('delivery_channel', 20)->default('telegram_bot');
            $table->unsignedBigInteger('registration_draft_id')->nullable();
            $table->unsignedBigInteger('user_id')->nullable();
            $table->unsignedBigInteger('otp_throttle_window_id');
            $table->dateTime('created_at')->useCurrent();
            $table->dateTime('updated_at')->useCurrent()->useCurrentOnUpdate();
            $table->foreign('purpose')->references('purpose_code')->on('otp_purpose_lookups');
            $table->foreign('state')->references('state_code')->on('otp_state_lookups');
            $table->foreign('registration_draft_id')->references('registration_draft_id')->on('registration_drafts');
            $table->foreign('user_id')->references('user_id')->on('user_accounts');
            $table->foreign('otp_throttle_window_id')
                ->references('otp_throttle_window_id')
                ->on('otp_throttle_windows');
            $table->index(['mobile_hash', 'purpose', 'state'], 'idx_otp_mobile_purpose_state');
            $table->index('registration_draft_id', 'idx_otp_registration_draft');
            $table->index('user_id', 'idx_otp_user');
            $table->index('otp_throttle_window_id', 'idx_otp_throttle_window');
            $table->index(['state', 'expires_at'], 'idx_otp_expiry_state');
        });

        Schema::create('user_telegram_identities', function (Blueprint $table) {
            $this->configure($table);
            $table->id('telegram_identity_id');
            $table->unsignedBigInteger('user_id')->nullable();
            $table->unsignedBigInteger('registration_draft_id')->nullable();
            $table->unsignedBigInteger('telegram_user_id')->unique();
            $table->bigInteger('chat_id')->unique();
            $table->string('username', 100)->nullable();
            $table->string('link_status', 15)->default('Pending');
            $table->binary('verified_mobile_hash', 32)->nullable();
            $table->dateTime('phone_verified_at')->nullable();
            $table->string('phone_verification_status', 15)->default('Pending');
            $table->dateTime('linked_at')->nullable();
            $table->dateTime('last_seen_at')->nullable();
            $table->dateTime('created_at')->useCurrent();
            $table->dateTime('updated_at')->useCurrent()->useCurrentOnUpdate();
            $table->foreign('user_id')->references('user_id')->on('user_profiles');
            $table->foreign('registration_draft_id')
                ->references('registration_draft_id')
                ->on('registration_drafts');
            $table->index(['user_id', 'link_status'], 'idx_telegram_user_account');
            $table->index(
                ['registration_draft_id', 'link_status'],
                'idx_telegram_registration_draft'
            );
            $table->index(
                ['verified_mobile_hash', 'phone_verification_status'],
                'idx_telegram_verified_mobile'
            );
            $table->index('link_status', 'idx_telegram_link_status');
        });

        Schema::create('integration_inbox_entries', function (Blueprint $table) {
            $this->configure($table);
            $table->id('inbox_entry_id');
            $table->string('channel', 32);
            $table->string('external_message_id', 64)->nullable();
            $table->binary('correlation_hash', 32)->nullable();
            $table->json('payload');
            $table->string('processed_status', 20)->default('Pending');
            $table->dateTime('received_at');
            $table->dateTime('processed_at')->nullable();
            $table->dateTime('created_at')->useCurrent();
            $table->dateTime('updated_at')->useCurrent()->useCurrentOnUpdate();
            $table->foreign('processed_status')
                ->references('status_code')
                ->on('integration_inbox_status_lookups');
            $table->unique(['channel', 'external_message_id'], 'uq_inbox_channel_external_id');
            $table->index(['correlation_hash', 'processed_status'], 'idx_inbox_correlation_status');
            $table->index(['processed_status', 'received_at'], 'idx_inbox_status_received');
        });

        Schema::create('otp_delivery_attempts', function (Blueprint $table) {
            $this->configure($table);
            $table->id('delivery_attempt_id');
            $table->unsignedBigInteger('otp_id');
            $table->unsignedBigInteger('telegram_identity_id')->nullable();
            $table->string('channel', 20)->default('telegram_bot');
            $table->string('provider_message_id', 128)->nullable();
            $table->unsignedTinyInteger('attempt_number')->default(1);
            $table->string('status', 20)->default('Queued');
            $table->string('failure_code', 64)->nullable();
            $table->dateTime('attempted_at')->useCurrent();
            $table->dateTime('delivered_at')->nullable();
            $table->dateTime('created_at')->useCurrent();
            $table->foreign('otp_id')->references('otp_id')->on('otps');
            $table->foreign('telegram_identity_id')
                ->references('telegram_identity_id')
                ->on('user_telegram_identities');
            $table->index(['telegram_identity_id', 'created_at'], 'idx_delivery_telegram_identity');
            $table->index(['otp_id', 'attempt_number'], 'idx_delivery_otp_attempt');
            $table->index(['status', 'created_at'], 'idx_delivery_status_created');
            $table->unique(['channel', 'provider_message_id'], 'uq_delivery_provider_message');
        });

        \Illuminate\Support\Facades\DB::statement("ALTER TABLE otps
            ADD CONSTRAINT chk_otp_attempt_count CHECK (attempt_count <= max_attempt_count),
            ADD CONSTRAINT chk_otp_max_attempts CHECK (max_attempt_count > 0),
            ADD CONSTRAINT chk_otp_channel CHECK (delivery_channel = 'telegram_bot')");
        \Illuminate\Support\Facades\DB::statement("ALTER TABLE user_telegram_identities
            ADD CONSTRAINT chk_telegram_link_status CHECK (link_status in ('Pending','Linked','Revoked')),
            ADD CONSTRAINT chk_telegram_phone_status CHECK (phone_verification_status in ('Pending','Verified','Revoked'))");
        \Illuminate\Support\Facades\DB::statement("ALTER TABLE integration_inbox_entries
            ADD CONSTRAINT chk_inbox_channel CHECK (channel in ('telegram','system'))");
        \Illuminate\Support\Facades\DB::statement("ALTER TABLE otp_delivery_attempts
            ADD CONSTRAINT chk_delivery_channel CHECK (channel = 'telegram_bot')");
    }

    public function down(): void
    {
        Schema::dropIfExists('otp_delivery_attempts');
        Schema::dropIfExists('integration_inbox_entries');
        Schema::dropIfExists('user_telegram_identities');
        Schema::dropIfExists('otps');
        Schema::dropIfExists('otp_throttle_windows');
    }
};
