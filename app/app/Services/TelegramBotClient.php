<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;
use RuntimeException;

class TelegramBotClient
{
    public function deleteWebhook(bool $dropPendingUpdates = false): void
    {
        $response = Http::asJson()
            ->timeout((int) config('services.telegram.timeout', 10))
            ->post($this->apiUrl('deleteWebhook'), [
                'drop_pending_updates' => $dropPendingUpdates,
            ]);

        if (!$response->successful() || !$response->json('ok')) {
            throw new RuntimeException('Telegram deleteWebhook failed.');
        }
    }

    public function getUpdates(?int $offset, int $longPollSeconds = 50): array
    {
        $payload = [
            'timeout' => $longPollSeconds,
            'limit' => 100,
            'allowed_updates' => ['message', 'callback_query'],
        ];
        if ($offset !== null) {
            $payload['offset'] = $offset;
        }

        $response = Http::asJson()
            ->timeout(max(65, $longPollSeconds + 15))
            ->post($this->apiUrl('getUpdates'), $payload);

        if (!$response->successful() || !$response->json('ok')) {
            $description = (string) $response->json('description', 'Telegram getUpdates failed.');
            throw new RuntimeException($description);
        }

        return (array) $response->json('result', []);
    }

    public function sendMessage(int $chatId, string $text): array
    {
        $response = Http::asJson()
            ->timeout((int) config('services.telegram.timeout', 10))
            ->post($this->apiUrl('sendMessage'), [
                'chat_id' => $chatId,
                'text' => $text,
            ]);

        if (! $response->successful() || ! $response->json('ok')) {
            throw new RuntimeException('Telegram sendMessage failed.');
        }

        return (array) $response->json('result');
    }

    public function requestContact(
        int $chatId,
        string $text = 'برای ادامه، Contact رسمی خودتان را ارسال کنید.',
    ): array
    {
        $response = Http::asJson()
            ->timeout((int) config('services.telegram.timeout', 10))
            ->post($this->apiUrl('sendMessage'), [
                'chat_id' => $chatId,
                'text' => $text,
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
        $response = Http::asJson()
            ->timeout((int) config('services.telegram.timeout', 10))
            ->post($this->apiUrl('setWebhook'), [
                'url' => $url,
                'secret_token' => $secretToken,
                'allowed_updates' => ['message', 'callback_query'],
            ]);

        if (! $response->successful() || ! $response->json('ok')) {
            throw new RuntimeException('Telegram setWebhook failed.');
        }

        return (array) $response->json('result');
    }

    private function apiUrl(string $method): string
    {
        $token = (string) config('services.telegram.bot_token');
        if ($token === '') {
            throw new RuntimeException('Telegram bot token is not configured.');
        }

        return "https://api.telegram.org/bot{$token}/{$method}";
    }
}
