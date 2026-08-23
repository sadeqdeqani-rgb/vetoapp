<?php

use App\Http\Controllers\AdminAuthController;
use App\Http\Controllers\AdminManagementController;
use App\Http\Controllers\NationalCodeController;
use App\Http\Controllers\TelegramWebhookController;
use App\Http\Middleware\AuthenticateSystemAdmin;
use Illuminate\Support\Facades\Route;

Route::post('/registration/validate-national-code', [
    NationalCodeController::class,
    'validateNationalCode',
]);

Route::post('/integrations/telegram/webhook/{secret}', TelegramWebhookController::class);

Route::prefix('admin')->group(function (): void {
    Route::post('/login', [AdminAuthController::class, 'login']);

    Route::middleware(AuthenticateSystemAdmin::class)->group(function (): void {
        Route::get('/me', [AdminAuthController::class, 'me']);
        Route::post('/logout', [AdminAuthController::class, 'logout']);
        Route::post('/users', [AdminAuthController::class, 'create']);

        Route::get('/countries', [AdminManagementController::class, 'countries']);

        Route::get('/introduction', [AdminManagementController::class, 'introduction']);
        Route::post('/introduction', [AdminManagementController::class, 'storeIntroduction']);
        Route::patch('/introduction/{id}', [AdminManagementController::class, 'updateIntroduction']);
        Route::post('/introduction/{id}/publish', [AdminManagementController::class, 'publishIntroduction']);

        Route::get('/terms', [AdminManagementController::class, 'terms']);
        Route::post('/terms', [AdminManagementController::class, 'storeTerms']);
        Route::patch('/terms/{id}', [AdminManagementController::class, 'updateTerms']);
        Route::post('/terms/{id}/publish', [AdminManagementController::class, 'publishTerms']);

        Route::get('/introduction-videos', [AdminManagementController::class, 'videos']);
        Route::post('/introduction-videos', [AdminManagementController::class, 'storeVideo']);
        Route::patch('/introduction-videos/{id}', [AdminManagementController::class, 'updateVideo']);
        Route::post('/introduction-videos/{id}/publish', [AdminManagementController::class, 'publishVideo']);

        Route::get('/provinces', [AdminManagementController::class, 'provinces']);
        Route::post('/provinces', [AdminManagementController::class, 'storeProvince']);
        Route::patch('/provinces/{id}', [AdminManagementController::class, 'updateProvince']);

        Route::get('/counties', [AdminManagementController::class, 'counties']);
        Route::post('/counties', [AdminManagementController::class, 'storeCounty']);
        Route::patch('/counties/{id}', [AdminManagementController::class, 'updateCounty']);

        Route::get('/settlements', [AdminManagementController::class, 'settlements']);
        Route::post('/settlements', [AdminManagementController::class, 'storeSettlement']);
        Route::patch('/settlements/{id}', [AdminManagementController::class, 'updateSettlement']);

        Route::get('/national-id-eligibilities', [AdminManagementController::class, 'nationalIdRanges']);
        Route::put('/national-id-eligibilities/{prefix}', [AdminManagementController::class, 'storeNationalIdRange']);
    });
});
