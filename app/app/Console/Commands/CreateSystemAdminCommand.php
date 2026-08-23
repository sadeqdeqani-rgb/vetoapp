<?php

namespace App\Console\Commands;

use App\Models\SystemAdmin;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

class CreateSystemAdminCommand extends Command
{
    protected $signature = 'admin:create
        {username : نام کاربری ادمین}
        {--password= : رمز عبور؛ در صورت نبودن به‌صورت تعاملی دریافت می‌شود}';

    protected $description = 'Create an active VetoApp system administrator';

    public function handle(): int
    {
        $username = (string) $this->argument('username');
        $password = (string) ($this->option('password') ?: $this->secret('رمز عبور ادمین (حداقل ۱۲ کاراکتر)'));

        if (strlen($password) < 12) {
            $this->error('رمز عبور باید حداقل ۱۲ کاراکتر باشد.');

            return self::FAILURE;
        }

        if (SystemAdmin::query()->where('username', $username)->exists()) {
            $this->error('این نام کاربری قبلاً ثبت شده است.');

            return self::FAILURE;
        }

        $admin = SystemAdmin::create([
            'admin_uuid' => Str::uuid()->getBytes(),
            'username' => $username,
            'password_hash' => Hash::make($password),
            'public_key_pem' => $this->generatePublicKey(),
            'is_active' => true,
        ]);

        $this->info("ادمین {$admin->username} با شناسه {$admin->admin_id} ایجاد شد.");

        return self::SUCCESS;
    }

    private function generatePublicKey(): string
    {
        $keyPair = sodium_crypto_sign_keypair();
        $publicKey = sodium_crypto_sign_publickey($keyPair);

        return "-----BEGIN VETOAPP ADMIN PUBLIC KEY-----\n"
            . base64_encode($publicKey)
            . "\n-----END VETOAPP ADMIN PUBLIC KEY-----";
    }
}
