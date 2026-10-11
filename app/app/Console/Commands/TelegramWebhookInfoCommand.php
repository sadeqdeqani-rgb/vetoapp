<?php

namespace App\Console\Commands;

use App\Services\TelegramBotClient;
use Illuminate\Console\Command;

class TelegramWebhookInfoCommand extends Command
{
    protected $signature = 'telegram:webhook:info {expected_url?}';
    protected $description = 'Show the Telegram webhook status without exposing bot credentials';

    public function handle(TelegramBotClient $telegram): int
    {
        try {
            $info = $telegram->getWebhookInfo();
        } catch (\Throwable $exception) {
            $this->error('Could not retrieve Telegram webhook status ('.$exception::class.').');

            return self::FAILURE;
        }

        $url = (string) ($info['url'] ?? '');
        $expectedUrl = (string) ($this->argument('expected_url') ?? '');
        $urlHost = parse_url($url, PHP_URL_HOST) ?: 'none';
        $this->line('url_host='.$urlHost);
        $this->line('url_configured='.($url !== '' ? 'yes' : 'no'));
        if ($expectedUrl !== '') {
            $this->line('url_matches_expected='.(hash_equals($expectedUrl, $url) ? 'yes' : 'no'));
        }
        $this->line('pending_update_count='.(int) ($info['pending_update_count'] ?? 0));
        $this->line('max_connections='.(int) ($info['max_connections'] ?? 0));
        $this->line('last_error_date='.(string) ($info['last_error_date'] ?? 'none'));
        $this->line('last_error_message='.(string) ($info['last_error_message'] ?? 'none'));

        return self::SUCCESS;
    }
}
