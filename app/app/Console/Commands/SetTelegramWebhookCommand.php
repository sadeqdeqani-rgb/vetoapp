<?php

namespace App\Console\Commands;

use App\Services\TelegramBotClient;
use Illuminate\Console\Command;

class SetTelegramWebhookCommand extends Command
{
    protected $signature = 'telegram:webhook:set {url : Public HTTPS webhook URL}';
    protected $description = 'Register the Telegram bot webhook with Telegram Bot API';

    public function handle(TelegramBotClient $telegram): int
    {
        $secret = (string) config('services.telegram.webhook_secret');
        if ($secret === '') {
            $this->error('TELEGRAM_WEBHOOK_SECRET is not configured.');
            return self::FAILURE;
        }

        $telegram->setWebhook((string) $this->argument('url'), $secret);
        $this->info('Telegram webhook registered successfully.');

        return self::SUCCESS;
    }
}
