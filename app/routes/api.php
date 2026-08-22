<?php

use App\Http\Controllers\NationalCodeController;
use App\Http\Controllers\TelegramWebhookController;
use Illuminate\Support\Facades\Route;

Route::post('/registration/validate-national-code', [
    NationalCodeController::class,
    'validateNationalCode',
]);

Route::post('/integrations/telegram/webhook/{secret}', TelegramWebhookController::class);
