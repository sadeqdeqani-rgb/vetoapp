<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;
use RuntimeException;

class TelegramBotClient
{
    public function sendMessage(int $chatId, string $text): array
    {
        $token = (string) config('services.telegram.bot_token');
        if ($token === '') {
            throw new RuntimeException('Telegram bot token is not configured.');
        }

        $response = Http::asJson()
            ->timeout((int) config('services.telegram.timeout', 10))
            ->post("https://api.telegram.org/bot{$token}/sendMessage", [
                'chat_id' => $chatId,
                'text' => $text,
            ]);

        if (! $response->successful() || ! $response->json('ok')) {
            throw new RuntimeException('Telegram sendMessage failed.');
        }

        return (array) $response->json('result');
    }

    public function requestContact(int $chatId): array
    {
        $token = (string) config('services.telegram.bot_token');
        if ($token === '') {
            throw new RuntimeException('Telegram bot token is not configured.');
        }

        $response = Http::asJson()
            ->timeout((int) config('services.telegram.timeout', 10))
            ->post("https://api.telegram.org/bot{$token}/sendMessage", [
                'chat_id' => $chatId,
                'text' => 'برای ادامه، Contact رسمی خودتان را ارسال کنید.',
                'reply_markup' => [
                    'keyboard' => [[
                        ['text' => 'ارسال شماره موبایل', 'request_contact' => true],
                    ]],
                    'resize_keyboard' => true,
                    'one_time_keyboard' => true,
                ],
            ]);

        if (! $response->successful() || ! $response->json('ok')) {
            throw new RuntimeException('Telegram contact request failed.');
        }

        return (array) $response->json('result');
    }

    public function setWebhook(string $url, string $secretToken): array
    {
        $token = (string) config('services.telegram.bot_token');
        if ($token === '') {
            throw new RuntimeException('Telegram bot token is not configured.');
        }

        $response = Http::asJson()
            ->timeout((int) config('services.telegram.timeout', 10))
            ->post("https://api.telegram.org/bot{$token}/setWebhook", [
                'url' => $url,
                'secret_token' => $secretToken,
                'allowed_updates' => ['message', 'callback_query'],
            ]);

        if (! $response->successful() || ! $response->json('ok')) {
            throw new RuntimeException('Telegram setWebhook failed.');
        }

        return (array) $response->json('result');
    }
}
