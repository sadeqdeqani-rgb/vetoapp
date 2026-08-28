<?php

namespace Tests\Feature;

use App\Jobs\ProcessTelegramWebhookJob;
use App\Jobs\TelegramSendMessageJob;
use App\Models\IntegrationInboxEntry;
use App\Models\UserTelegramIdentity;
use App\Services\OtpService;
use App\Services\RegistrationTransactionService;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Queue;
use Illuminate\Support\Facades\Schema;
use Tests\TestCase;

class OtpAndTelegramIntegrationTest extends TestCase
{
    use DatabaseTransactions;
    use CreatesTestGeography;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(\Database\Seeders\VetoAppLookupSeeder::class);
        $this->seedTestGeography();
    }

    public function test_registration_otp_is_two_minutes_and_queued_for_verified_identity(): void
    {
        Queue::fake();
        $registration = app(RegistrationTransactionService::class);
        $otpService = app(OtpService::class);
        $draft = $registration->createDraft('09121234601', 'otp-test-issue-1');
        $nonce = $registration->issueTelegramLinkNonce($draft);
        $identity = $registration->verifyTelegramContact(
            $draft,
            $nonce,
            ['telegram_user_id' => 910001, 'chat_id' => 910001],
            ['user_id' => 910001, 'phone_number' => '09121234601'],
        );

        $otp = $otpService->issueForRegistration($draft, $identity->telegram_identity_id);

        $this->assertSame('Issued', $otp->state);
        $this->assertEquals(120, $otp->issued_at->diffInSeconds($otp->expires_at));
        $this->assertSame(0, DB::table('otps')->where('otp_id', $otp->otp_id)->where('code_hash', '')->count());
        Queue::assertPushed(TelegramSendMessageJob::class);
    }

    public function test_successful_otp_sets_mobile_verified_at_atomically(): void
    {
        Queue::fake();
        $registration = app(RegistrationTransactionService::class);
        $otpService = app(OtpService::class);
        $draft = $registration->createDraft('09121234602', 'otp-test-verify-1');
        $nonce = $registration->issueTelegramLinkNonce($draft);
        $identity = $registration->verifyTelegramContact(
            $draft,
            $nonce,
            ['telegram_user_id' => 910002, 'chat_id' => 910002],
            ['user_id' => 910002, 'phone_number' => '09121234602'],
        );
        $otp = $otpService->issueForRegistration($draft, $identity->telegram_identity_id);
        $encryptedCode = null;

        Queue::assertPushed(TelegramSendMessageJob::class, function (TelegramSendMessageJob $job) use (&$encryptedCode, $otp): bool {
            $encryptedCode = $job->encryptedCode;
            return true;
        });

        $verified = $otpService->verify(
            Crypt::decryptString($encryptedCode),
            $otp->otp_id
        );

        $this->assertSame('Verified', $verified->state);
        $this->assertNotNull($draft->refresh()->mobile_verified_at);
        $this->assertSame('National_ID_Verification', $draft->step_code);
    }

    public function test_webhook_persists_payload_and_deduplicates_update_id(): void
    {
        Queue::fake();
        config(['services.telegram.webhook_secret' => 'test-webhook-secret']);
        $payload = [
            'update_id' => 990001,
            'message' => [
                'message_id' => 12,
                'from' => ['id' => 920001],
                'chat' => ['id' => 920001, 'type' => 'private'],
                'text' => '/start test-nonce',
            ],
        ];

        $first = $this->postJson('/api/integrations/telegram/webhook/test-webhook-secret', $payload);
        $second = $this->postJson('/api/integrations/telegram/webhook/test-webhook-secret', $payload);

        $first->assertOk();
        $second->assertOk();
        $this->assertSame(1, IntegrationInboxEntry::query()->where('external_message_id', '990001')->count());
        Queue::assertPushed(\App\Jobs\ProcessTelegramWebhookJob::class, 1);
    }

    public function test_webhook_job_handles_start_then_official_contact(): void
    {
        config(['services.telegram.bot_token' => 'test-bot-token']);
        Http::fake([
            'https://api.telegram.org/*/sendMessage' => Http::response([
                'ok' => true,
                'result' => ['message_id' => 123],
            ]),
        ]);

        $registration = app(RegistrationTransactionService::class);
        $draft = $registration->createDraft('09121234603', 'webhook-job-start-1');
        $nonce = $registration->issueTelegramLinkNonce($draft);
        $telegramUserId = 930001;
        $chatId = 930001;

        $start = IntegrationInboxEntry::query()->create([
            'channel' => 'telegram',
            'external_message_id' => '990002',
            'correlation_hash' => hash('sha256', '990002', true),
            'payload' => [
                'update_id' => 990002,
                'message' => [
                    'from' => ['id' => $telegramUserId, 'username' => 'webhook_user'],
                    'chat' => ['id' => $chatId],
                    'text' => '/start '.$nonce,
                ],
            ],
            'processed_status' => 'Pending',
            'received_at' => now(),
        ]);

        app(ProcessTelegramWebhookJob::class, ['inboxEntryId' => $start->inbox_entry_id])
            ->handle(app(\App\Services\RegistrationTransactionService::class), app(\App\Services\TelegramBotClient::class));

        $this->assertSame('Pending', UserTelegramIdentity::query()->firstOrFail()->phone_verification_status);
        $this->assertNotNull(Cache::get("telegram:registration:nonce:{$telegramUserId}"));

        $contact = IntegrationInboxEntry::query()->create([
            'channel' => 'telegram',
            'external_message_id' => '990003',
            'correlation_hash' => hash('sha256', '990003', true),
            'payload' => [
                'update_id' => 990003,
                'message' => [
                    'from' => ['id' => $telegramUserId],
                    'chat' => ['id' => $chatId],
                    'contact' => [
                        'user_id' => $telegramUserId,
                        'phone_number' => '09121234603',
                    ],
                ],
            ],
            'processed_status' => 'Pending',
            'received_at' => now(),
        ]);

        app(ProcessTelegramWebhookJob::class, ['inboxEntryId' => $contact->inbox_entry_id])
            ->handle(app(\App\Services\RegistrationTransactionService::class), app(\App\Services\TelegramBotClient::class));

        $this->assertSame('Verified', UserTelegramIdentity::query()->firstOrFail()->phone_verification_status);
        $this->assertNull(Cache::get("telegram:registration:nonce:{$telegramUserId}"));
        Http::assertSentCount(2);
    }
}
