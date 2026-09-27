<?php

namespace App\Http\Controllers;

use App\Services\TelegramUpdateIngestor;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class TelegramWebhookController extends Controller
{
    public function __invoke(Request $request, string $secret, TelegramUpdateIngestor $ingestor): JsonResponse
    {
        $configured = (string) config('services.telegram.webhook_secret');
        $headerSecret = (string) $request->header('X-Telegram-Bot-Api-Secret-Token');
        if (
            $configured === ''
            || (! hash_equals($configured, $secret)
                && ($headerSecret === '' || ! hash_equals($configured, $headerSecret)))
        ) {
            return response()->json(['ok' => true]);
        }

        $ingestor->ingest($request->json()->all());

        return response()->json(['ok' => true]);
    }
}
