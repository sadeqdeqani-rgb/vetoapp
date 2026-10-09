<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        if (DB::getDriverName() !== 'mysql') {
            throw new RuntimeException('Vote-receipt account-link enforcement currently requires MySQL.');
        }

        $legacyUnlinked = DB::table('digital_receipts')
            ->where('receipt_type_code', 'VOTE')
            ->whereNull('beneficiary_user_account_id')
            ->exists();
        if ($legacyUnlinked) {
            throw new RuntimeException(
                'Unlinked historical VOTE receipts exist. They cannot be assigned to accounts safely; resolve them before this migration.'
            );
        }

        // MySQL DDL is not transactional; tolerate a rerun if a prior attempt
        // replaced the CHECK constraint but failed before Laravel recorded it.
        $checkExists = DB::table('information_schema.TABLE_CONSTRAINTS')
            ->where('CONSTRAINT_SCHEMA', DB::getDatabaseName())
            ->where('TABLE_NAME', 'digital_receipts')
            ->where('CONSTRAINT_NAME', 'chk_receipt_support_identity')
            ->exists();
        if ($checkExists) DB::statement('ALTER TABLE digital_receipts DROP CHECK chk_receipt_support_identity');
        DB::statement("ALTER TABLE digital_receipts ADD CONSTRAINT chk_receipt_support_identity CHECK (
            (receipt_type_code = 'SUPPORT' AND beneficiary_user_account_id IS NOT NULL
             AND participant_identity_key IS NOT NULL AND support_idempotency_key IS NOT NULL)
            OR (receipt_type_code = 'VOTE' AND beneficiary_user_account_id IS NOT NULL
                AND participant_identity_key IS NULL AND support_idempotency_key IS NULL)
        )");
    }

    public function down(): void
    {
        if (DB::getDriverName() !== 'mysql') return;

        DB::statement('ALTER TABLE digital_receipts DROP CHECK chk_receipt_support_identity');
        // Keep both linked and legacy receipts intact if this migration is rolled back.
        DB::statement("ALTER TABLE digital_receipts ADD CONSTRAINT chk_receipt_support_identity CHECK (
            (receipt_type_code = 'SUPPORT' AND beneficiary_user_account_id IS NOT NULL
             AND participant_identity_key IS NOT NULL AND support_idempotency_key IS NOT NULL)
            OR (receipt_type_code = 'VOTE' AND participant_identity_key IS NULL AND support_idempotency_key IS NULL)
        )");
    }
};
