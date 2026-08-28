<?php

use App\Http\Controllers\AdminAuthController;
use App\Http\Controllers\AdminManagementController;
use App\Http\Controllers\AdminPolicyController;
use App\Http\Controllers\GeographicalAreaController;
use App\Http\Controllers\NationalCodeController;
use App\Http\Controllers\OtpApiController;
use App\Http\Controllers\PublicContentController;
use App\Http\Controllers\ProfileController;
use App\Http\Controllers\RegistrationApiController;
use App\Http\Controllers\TelegramWebhookController;
use App\Http\Controllers\UserAuthController;
use App\Http\Middleware\AuthenticateSystemAdmin;
use App\Http\Middleware\AuthenticateUserSession;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->group(function (): void {
    Route::post('/auth/login', [UserAuthController::class, 'login']);
    Route::post('/auth/otp/request', [OtpApiController::class, 'requestOtp']);
    Route::post('/auth/otp/verify', [OtpApiController::class, 'verifyOtp']);
    Route::post('/auth/password/reset', [OtpApiController::class, 'resetPassword']);

    Route::post('/auth/registration/drafts', [
        RegistrationApiController::class,
        'createDraft',
    ]);
    Route::post('/auth/registration/drafts/{draft}/details', [
        RegistrationApiController::class,
        'selectDetails',
    ]);
    Route::get('/auth/registration/drafts/{draft}/status', [
        RegistrationApiController::class,
        'status',
    ]);
    Route::post('/auth/registration/complete', [
        RegistrationApiController::class,
        'complete',
    ]);

    Route::get('/geographical-areas', [GeographicalAreaController::class, 'index']);
    Route::prefix('content')->group(function (): void {
        Route::get('/introduction', [PublicContentController::class, 'introduction']);
        Route::get('/terms', [PublicContentController::class, 'terms']);
        Route::get('/introduction-video', [PublicContentController::class, 'introductionVideo']);
    });
    Route::post('/registration/validate-national-code', [
        NationalCodeController::class,
        'validateNationalCode',
    ]);

    Route::middleware(AuthenticateUserSession::class)->group(function (): void {
        Route::post('/auth/logout', [UserAuthController::class, 'logout']);
        Route::post('/auth/session/heartbeat', [UserAuthController::class, 'heartbeat']);
        Route::get('/profile', [ProfileController::class, 'show']);
        Route::post('/profile/close', [ProfileController::class, 'close']);
    });
});

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

        Route::get('/geo-cooldown-policies', [AdminPolicyController::class, 'geoCooldownPolicies']);
        Route::post('/geo-cooldown-policies', [AdminPolicyController::class, 'storeGeoCooldownPolicy']);
        Route::patch('/geo-cooldown-policies/{id}', [AdminPolicyController::class, 'updateGeoCooldownPolicy']);
        Route::delete('/geo-cooldown-policies/{id}', [AdminPolicyController::class, 'deleteGeoCooldownPolicy']);

        Route::get('/account-closure-penalty-policies', [AdminPolicyController::class, 'accountClosurePenaltyPolicies']);
        Route::post('/account-closure-penalty-policies', [AdminPolicyController::class, 'storeAccountClosurePenaltyPolicy']);
        Route::patch('/account-closure-penalty-policies/{id}', [AdminPolicyController::class, 'updateAccountClosurePenaltyPolicy']);
        Route::delete('/account-closure-penalty-policies/{id}', [AdminPolicyController::class, 'deleteAccountClosurePenaltyPolicy']);
    });
});
