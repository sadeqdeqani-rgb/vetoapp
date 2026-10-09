<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Str;

class GenerateProcessReceiptKeyCommand extends Command
{
    protected $signature = 'process-receipts:generate-key {--key-id= : Optional immutable key identifier}';
    protected $description = 'Generate an Ed25519 key pair dedicated to signing VetoApp process receipts';

    public function handle(): int
    {
        $pair = sodium_crypto_sign_keypair();
        $secret = sodium_crypto_sign_secretkey($pair);
        $public = sodium_crypto_sign_publickey($pair);
        $keyId = (string) ($this->option('key-id') ?: 'receipt-ed25519-'.Str::uuid());

        $this->newLine();
        $this->line('PROCESS_RECEIPT_KEY_ID='.$keyId);
        $this->line('PROCESS_RECEIPT_PRIVATE_KEY='.base64_encode($secret));
        $this->line('PROCESS_RECEIPT_PUBLIC_KEY='.base64_encode($public));
        $this->newLine();
        $this->warn('کلید خصوصی را فقط در secret store یا فایل محیطی با دسترسی محدود نگه دارید؛ آن را در مخزن کد، دیتابیس یا لاگ‌ها قرار ندهید.');
        sodium_memzero($secret);

        return self::SUCCESS;
    }
}
