<?php

namespace Tests\Feature;

use App\Models\RegistrationDraft;
use App\Services\RegistrationTransactionService;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use RuntimeException;
use Tests\TestCase;

class RegistrationTransactionServiceTest extends TestCase
{
    use DatabaseTransactions;

    protected function setUp(): void
    {
        parent::setUp();

        if (
            DB::getDriverName() !== 'mysql'
            || ! Schema::hasTable('registration_drafts')
            || DB::table('countries')->count() === 0
        ) {
            $this->markTestSkipped('These tests require the migrated and seeded MySQL database.');
        }
    }

    public function test_registration_contact_and_account_creation_are_atomic(): void
    {
        $service = app(RegistrationTransactionService::class);
        $draft = $service->createDraft('09121234567', 'test-registration-atomic-1');
        $nonce = $service->issueTelegramLinkNonce($draft);

        $identity = $service->verifyTelegramContact(
            $draft,
            $nonce,
            ['telegram_user_id' => 900001, 'chat_id' => 900001, 'username' => 'test_user'],
            ['user_id' => 900001, 'phone_number' => '09121234567'],
        );

        $this->assertSame('Verified', $identity->phone_verification_status);
        $this->assertSame($draft->registration_draft_id, $identity->registration_draft_id);

        $settlementCode = (int) DB::table('settlements')->orderBy('settlement_code')->value('settlement_code');
        $draft = $service->selectNationalIdAndSettlement($draft, '1234567890', $settlementCode);
        $draft->forceFill(['mobile_verified_at' => now()])->save();

        $result = $service->completeRegistration($draft, $identity->telegram_identity_id, 'StrongPassword!123');

        $this->assertSame('Completed', $result['draft']->state_code);
        $this->assertSame('Active', $result['account']->account_status);
        $this->assertSame($result['profile']->user_id, $result['account']->user_id);
        $this->assertSame($result['profile']->user_id, $result['identity']->user_id);
        $this->assertNull($result['identity']->registration_draft_id);
    }

    public function test_contact_must_belong_to_sender_and_match_draft_mobile(): void
    {
        $service = app(RegistrationTransactionService::class);
        $draft = $service->createDraft('09121234568', 'test-registration-contact-1');
        $nonce = $service->issueTelegramLinkNonce($draft);

        $this->expectException(RuntimeException::class);

        $service->verifyTelegramContact(
            $draft,
            $nonce,
            ['telegram_user_id' => 900002, 'chat_id' => 900002],
            ['user_id' => 900003, 'phone_number' => '09121234568'],
        );
    }

    public function test_registration_nonce_is_single_use(): void
    {
        $service = app(RegistrationTransactionService::class);
        $draft = $service->createDraft('09121234569', 'test-registration-nonce-1');
        $nonce = $service->issueTelegramLinkNonce($draft);
        $telegram = ['telegram_user_id' => 900004, 'chat_id' => 900004];
        $contact = ['user_id' => 900004, 'phone_number' => '09121234569'];

        $service->verifyTelegramContact($draft, $nonce, $telegram, $contact);

        $this->expectException(RuntimeException::class);
        $service->verifyTelegramContact($draft, $nonce, $telegram, $contact);
    }

    public function test_failed_completion_rolls_back_profile_and_account_creation(): void
    {
        $service = app(RegistrationTransactionService::class);
        $draft = $service->createDraft('09121234570', 'test-registration-rollback-1');
        $nonce = $service->issueTelegramLinkNonce($draft);
        $identity = $service->verifyTelegramContact(
            $draft,
            $nonce,
            ['telegram_user_id' => 900005, 'chat_id' => 900005],
            ['user_id' => 900005, 'phone_number' => '09121234570'],
        );

        $draft = $service->selectNationalIdAndSettlement(
            $draft,
            '1234567891',
            (int) DB::table('settlements')->orderBy('settlement_code')->value('settlement_code')
        );
        $draft->forceFill(['mobile_verified_at' => now()])->save();

        try {
            $service->completeRegistration($draft, $identity->telegram_identity_id, '');
            $this->fail('Completion should reject an empty password.');
        } catch (RuntimeException) {
            $this->assertSame(0, DB::table('user_profiles')->where('mobile_hash', $draft->mobile_hash)->count());
            $this->assertSame(0, DB::table('user_accounts')->count());
            $this->assertSame('Initiated', $draft->refresh()->state_code);
        }
    }
}
