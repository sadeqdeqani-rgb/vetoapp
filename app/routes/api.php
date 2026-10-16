<?php

use App\Http\Controllers\AdminAuthController;
use App\Http\Controllers\ActivationRequestController;
use App\Http\Controllers\AdminManagementController;
use App\Http\Controllers\AdminPolicyController;
use App\Http\Controllers\AdminReferendumPolicyController;
use App\Http\Controllers\BiometricAuthController;
use App\Http\Controllers\DashboardController;
use App\Http\Controllers\GeographicalAreaController;
use App\Http\Controllers\HomeManagementController;
use App\Http\Controllers\WordPressContentManagementController;
use App\Http\Controllers\NationalCodeController;
use App\Http\Controllers\OtpApiController;
use App\Http\Controllers\ProfileController;
use App\Http\Controllers\PublicContentController;
use App\Http\Controllers\RegistrationApiController;
use App\Http\Controllers\ReferendumProposalController;
use App\Http\Controllers\ReferendumVotingController;
use App\Http\Controllers\ElectionVotingController;
use App\Http\Controllers\ImpeachmentProcessController;
use App\Http\Controllers\ImpeachmentVotingController;
use App\Http\Controllers\TelegramPasswordRecoveryController;
use App\Http\Controllers\TelegramWebhookController;
use App\Http\Controllers\UserAuthController;
use App\Http\Middleware\AuthenticateSystemAdmin;
use App\Http\Middleware\AuthenticateUserSession;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->group(function (): void {
    Route::get('/home/introduction', [HomeManagementController::class, 'publicSections']);
    Route::get('/home/gateway-introduction', [HomeManagementController::class, 'publicGatewayIntroduction']);
    Route::get('/public/active-users', [DashboardController::class, 'publicActiveUsers']);
    Route::get('/public/geography-user-counts', [DashboardController::class, 'publicGeographyUserCounts']);
    Route::get('/public/activation-requests/count', [ActivationRequestController::class, 'count']);
    Route::post('/public/activation-requests', [ActivationRequestController::class, 'store']);
    Route::post('/auth/login', [UserAuthController::class, 'login']);
    Route::post('/auth/biometric/login/challenge', [BiometricAuthController::class, 'loginChallenge']);
    Route::post('/auth/biometric/login/verify', [BiometricAuthController::class, 'verifyLogin']);
    Route::post('/auth/otp/request', [OtpApiController::class, 'requestOtp']);
    Route::post('/auth/otp/verify', [OtpApiController::class, 'verifyOtp']);
    Route::post('/auth/password/reset', [OtpApiController::class, 'resetPassword']);
    Route::post('/auth/password-recovery/telegram', [TelegramPasswordRecoveryController::class, 'start']);
    Route::get('/auth/password-recovery/telegram/status', [TelegramPasswordRecoveryController::class, 'status']);

    Route::post('/auth/registration/drafts', [
        RegistrationApiController::class,
        'createDraft',
    ]);
    Route::post('/auth/registration/drafts/{draft}/details', [
        RegistrationApiController::class,
        'selectDetails',
    ]);
    Route::post('/auth/registration/drafts/{draft}/validate-national-code', [RegistrationApiController::class, 'validateDraftNationalCode']);
    Route::post('/auth/registration/drafts/{draft}/age-eligibility-reports', [RegistrationApiController::class, 'submitAgeEligibilityReport']);
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
    Route::get('/public/process-receipt-keys', [ReferendumProposalController::class, 'receiptKeys']);
    Route::post('/public/process-receipts/verify', [ReferendumProposalController::class, 'verifyReceipt']);

    Route::middleware(AuthenticateUserSession::class)->group(function (): void {
        Route::get('/dashboard/summary', [DashboardController::class, 'summary']);
        Route::post('/referendum/proposals/preview', [ReferendumProposalController::class, 'preview']);
        Route::post('/referendum/proposals/similar', [ReferendumProposalController::class, 'similar']);
        Route::post('/referendum/proposals/biometric-challenge', [ReferendumProposalController::class, 'biometricChallenge']);
        Route::post('/referendum/proposals/commit', [ReferendumProposalController::class, 'commit']);
        Route::get('/referendum/proposals', [ReferendumProposalController::class, 'index']);
        Route::get('/referendum/proposals/{processId}/support-breakdown', [ReferendumProposalController::class, 'supportBreakdown'])->whereNumber('processId');
        Route::get('/referendum/proposals/{processId}', [ReferendumProposalController::class, 'show'])->whereNumber('processId');
        Route::get('/referendum/voting/{kind}', [ReferendumVotingController::class, 'index'])->whereIn('kind', ['scheduled', 'eligible', 'live', 'finalized']);
        Route::get('/referendum/voting/{processId}/results', [ReferendumVotingController::class, 'results'])->whereNumber('processId');
        Route::get('/referendum/voting/{processId}', [ReferendumVotingController::class, 'show'])->whereNumber('processId');
        Route::post('/referendum/voting/{processId}/biometric-challenge', [ReferendumVotingController::class, 'biometricChallenge'])->whereNumber('processId');
        Route::post('/referendum/voting/{processId}/confirmation', [ReferendumVotingController::class, 'confirmation'])->whereNumber('processId');
        Route::post('/referendum/voting/{processId}/votes', [ReferendumVotingController::class, 'cast'])->whereNumber('processId');
        Route::get('/elections/{electionType}/voting/{kind}', [ElectionVotingController::class, 'index'])
            ->whereIn('electionType', ['presidential', 'governor', 'county', 'local'])
            ->whereIn('kind', ['scheduled', 'eligible', 'live', 'finalized']);
        Route::get('/elections/{electionType}/voting/{processId}/results', [ElectionVotingController::class, 'results'])
            ->whereIn('electionType', ['presidential', 'governor', 'county', 'local'])->whereNumber('processId');
        Route::get('/elections/{electionType}/voting/{processId}', [ElectionVotingController::class, 'show'])
            ->whereIn('electionType', ['presidential', 'governor', 'county', 'local'])->whereNumber('processId');
        Route::post('/elections/{electionType}/voting/{processId}/candidate-preview', [ElectionVotingController::class, 'candidatePreview'])
            ->whereIn('electionType', ['presidential', 'governor', 'county', 'local'])->whereNumber('processId');
        Route::post('/elections/{electionType}/voting/{processId}/biometric-challenge', [ElectionVotingController::class, 'biometricChallenge'])
            ->whereIn('electionType', ['presidential', 'governor', 'county', 'local'])->whereNumber('processId');
        Route::post('/elections/{electionType}/voting/{processId}/confirmation', [ElectionVotingController::class, 'confirmation'])
            ->whereIn('electionType', ['presidential', 'governor', 'county', 'local'])->whereNumber('processId');
        Route::post('/elections/{electionType}/voting/{processId}/votes', [ElectionVotingController::class, 'cast'])
            ->whereIn('electionType', ['presidential', 'governor', 'county', 'local'])->whereNumber('processId');
        Route::get('/impeachment/{office}/processes/{kind}', [ImpeachmentProcessController::class, 'index'])
            ->whereIn('office', ['president', 'governor', 'county', 'local'])
            ->whereIn('kind', ['supporting', 'scheduled', 'eligible', 'live', 'finalized']);
        Route::post('/impeachment/{office}/requests', [ImpeachmentProcessController::class, 'requestImpeachment'])
            ->whereIn('office', ['president', 'governor', 'county', 'local']);
        Route::get('/impeachment/{office}/current', [ImpeachmentProcessController::class, 'current'])
            ->whereIn('office', ['president', 'governor', 'county', 'local']);
        Route::get('/impeachment/{office}/processes/{processId}', [ImpeachmentProcessController::class, 'show'])
            ->whereIn('office', ['president', 'governor', 'county', 'local'])->whereNumber('processId');
        Route::post('/impeachment/{office}/processes/{processId}/support', [ImpeachmentProcessController::class, 'support'])
            ->whereIn('office', ['president', 'governor', 'county', 'local'])->whereNumber('processId');
        Route::get('/impeachment/{office}/voting/{kind}', [ImpeachmentVotingController::class, 'index'])
            ->whereIn('office', ['president', 'governor', 'county', 'local'])->whereIn('kind', ['scheduled', 'eligible', 'live', 'finalized']);
        Route::get('/impeachment/{office}/voting/{processId}/results', [ImpeachmentVotingController::class, 'results'])
            ->whereIn('office', ['president', 'governor', 'county', 'local'])->whereNumber('processId');
        Route::get('/impeachment/{office}/voting/{processId}', [ImpeachmentVotingController::class, 'show'])
            ->whereIn('office', ['president', 'governor', 'county', 'local'])->whereNumber('processId');
        Route::post('/impeachment/{office}/voting/{processId}/biometric-challenge', [ImpeachmentVotingController::class, 'biometricChallenge'])
            ->whereIn('office', ['president', 'governor', 'county', 'local'])->whereNumber('processId');
        Route::post('/impeachment/{office}/voting/{processId}/confirmation', [ImpeachmentVotingController::class, 'confirmation'])
            ->whereIn('office', ['president', 'governor', 'county', 'local'])->whereNumber('processId');
        Route::post('/impeachment/{office}/voting/{processId}/votes', [ImpeachmentVotingController::class, 'cast'])
            ->whereIn('office', ['president', 'governor', 'county', 'local'])->whereNumber('processId');
        Route::post('/auth/logout', [UserAuthController::class, 'logout']);
        Route::post('/auth/session/heartbeat', [UserAuthController::class, 'heartbeat']);
        Route::get('/auth/biometric/status', [BiometricAuthController::class, 'status']);
        Route::get('/auth/biometric/enrollment-challenge', [BiometricAuthController::class, 'enrollmentChallenge']);
        Route::post('/auth/biometric/enroll', [BiometricAuthController::class, 'enroll']);
        Route::delete('/auth/biometric/credential', [BiometricAuthController::class, 'revoke']);
        Route::get('/profile', [ProfileController::class, 'show']);
        Route::get('/profile/receipts', [ProfileController::class, 'receipts']);
        Route::get('/profile/notifications', [ProfileController::class, 'notifications']);
        Route::post('/profile/notifications/{notificationId}/read', [ProfileController::class, 'markNotificationRead'])->whereNumber('notificationId');
        Route::post('/profile/password/verify', [ProfileController::class, 'verifyPassword']);
        Route::post('/profile/password/change', [ProfileController::class, 'changePassword']);
        Route::get('/profile/geography', [ProfileController::class, 'geography']);
        Route::post('/profile/geography', [ProfileController::class, 'changeGeography']);
        Route::get('/profile/closure-policy', [ProfileController::class, 'closurePolicy']);
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
        Route::get('/home/sections', [HomeManagementController::class, 'sections']);
        Route::put('/home/sections/{key}', [HomeManagementController::class, 'saveSection']);
        Route::get('/home/state', [HomeManagementController::class, 'state']);
        Route::post('/home/state', [HomeManagementController::class, 'changeState']);
        Route::get('/home/events', [HomeManagementController::class, 'events']);

        Route::get('/wordpress/content', [WordPressContentManagementController::class, 'show']);
        Route::put('/wordpress/settings', [WordPressContentManagementController::class, 'updateSettings']);
        Route::patch('/wordpress/pages/{pageId}', [WordPressContentManagementController::class, 'updatePage'])->whereNumber('pageId');
        Route::patch('/wordpress/collections/{type}/{itemId}', [WordPressContentManagementController::class, 'updateCollectionItem'])->whereNumber('itemId');
        Route::post('/wordpress/media', [WordPressContentManagementController::class, 'uploadMedia']);

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
        Route::get('/national-id-age-eligibility-reports', [AdminManagementController::class, 'ageEligibilityReports']);
        Route::patch('/national-id-age-eligibility-reports/{reportId}', [AdminManagementController::class, 'updateAgeEligibilityReport']);

        Route::get('/geo-cooldown-policies', [AdminPolicyController::class, 'geoCooldownPolicies']);
        Route::post('/geo-cooldown-policies', [AdminPolicyController::class, 'storeGeoCooldownPolicy']);
        Route::patch('/geo-cooldown-policies/{id}', [AdminPolicyController::class, 'updateGeoCooldownPolicy']);
        Route::delete('/geo-cooldown-policies/{id}', [AdminPolicyController::class, 'deleteGeoCooldownPolicy']);

        Route::get('/account-closure-penalty-policies', [AdminPolicyController::class, 'accountClosurePenaltyPolicies']);
        Route::post('/account-closure-penalty-policies', [AdminPolicyController::class, 'storeAccountClosurePenaltyPolicy']);
        Route::patch('/account-closure-penalty-policies/{id}', [AdminPolicyController::class, 'updateAccountClosurePenaltyPolicy']);
        Route::delete('/account-closure-penalty-policies/{id}', [AdminPolicyController::class, 'deleteAccountClosurePenaltyPolicy']);

        Route::get('/process-lifecycle-policies', [AdminPolicyController::class, 'processLifecyclePolicies']);
        Route::post('/process-lifecycle-policies', [AdminPolicyController::class, 'createProcessLifecyclePolicy']);
        Route::get('/referendum-directional-terms', [AdminReferendumPolicyController::class, 'directionalTerms']);
        Route::post('/referendum-directional-terms', [AdminReferendumPolicyController::class, 'storeDirectionalTerm']);
        Route::patch('/referendum-directional-terms/{id}', [AdminReferendumPolicyController::class, 'updateDirectionalTerm']);
    });
});
