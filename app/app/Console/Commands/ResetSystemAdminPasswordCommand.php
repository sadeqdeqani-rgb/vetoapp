<?php

namespace App\Console\Commands;

use App\Models\SystemAdmin;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Hash;

class ResetSystemAdminPasswordCommand extends Command
{
    protected $signature = 'admin:password
        {username : نام کاربری ادمین}
        {--password= : رمز جدید؛ در صورت نبودن به‌صورت تعاملی دریافت می‌شود}';

    protected $description = 'Reset a VetoApp system administrator password';

    public function handle(): int
    {
        $admin = SystemAdmin::query()
            ->where('username', (string) $this->argument('username'))
            ->first();

        if ($admin === null) {
            $this->error('ادمین موردنظر پیدا نشد.');

            return self::FAILURE;
        }

        $password = (string) (
            $this->option('password')
            ?: $this->secret('رمز عبور جدید (حداقل ۱۲ کاراکتر)')
        );

        if (strlen($password) < 12) {
            $this->error('رمز عبور باید حداقل ۱۲ کاراکتر باشد.');

            return self::FAILURE;
        }

        $admin->forceFill([
            'password_hash' => Hash::make($password),
        ])->save();

        $admin->apiTokens()->whereNull('revoked_at')->update([
            'revoked_at' => now(),
        ]);

        $this->info("رمز عبور ادمین {$admin->username} تغییر کرد.");
        $this->line('نشست‌های قبلی این ادمین نیز باطل شدند.');

        return self::SUCCESS;
    }
}
