<?php

namespace App\Http\Controllers;

use App\Models\RegistrationDraft;
use App\Services\RegistrationTransactionService;
use App\Support\MobileNumber;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;

class RegistrationApiController extends Controller
{
    public function __construct(private readonly RegistrationTransactionService $registrations) {}

    public function createDraft(Request $request): JsonResponse
    {
        $data = $request->validate([
            'phone_number' => ['required', 'string'],
            'idempotency_key' => ['required', 'string', 'max:80'],
        ]);

        try {
            $mobile = MobileNumber::normalize($data['phone_number']);
        } catch (\InvalidArgumentException) {
            throw ValidationException::withMessages([
                'phone_number' => ['شماره موبایل معتبر نیست.'],
            ]);
        }

        if ($this->registrations->mobileAlreadyRegistered($mobile)) {
            $message = 'این شماره موبایل قبلاً در اپ ثبت‌نام کرده است؛ شما نمی‌توانید با این شماره ثبت‌نام جدیدی انجام دهید.';

            return response()->json([
                'code' => 'mobile_already_registered',
                'message' => $message,
                'errors' => ['phone_number' => [$message]],
            ], 409);
        }

        $draft = $this->registrations->createDraft($mobile, $data['idempotency_key']);
        $nonce = $this->registrations->issueTelegramLinkNonce($draft);

        return response()->json([
            'draft_id' => (string) $draft->registration_draft_id,
            'step' => $draft->step_code,
            'expires_at' => $draft->expires_at?->toISOString(),
            'telegram_link_nonce' => $nonce,
            'telegram_start_url' => $this->telegramStartUrl($nonce),
        ], 201);
    }

    public function selectDetails(Request $request, int $draft): JsonResponse
    {
        $data = $request->validate([
            'national_code' => ['required', 'string', 'regex:/^[0-9۰-۹٠-٩]{10}$/'],
            'settlement_id' => ['required', 'integer', 'min:1'],
        ]);

        $record = RegistrationDraft::query()->findOrFail($draft);
        $assessment = $this->registrations->validateNationalIdForDraft($record, $data['national_code']);
        if (($assessment['valid'] ?? false) !== true) {
            return $this->nationalCodeError($assessment);
        }
        $updated = $this->registrations->selectNationalIdAndSettlement($record, $data['national_code'], (int) $data['settlement_id']);

        return response()->json([
            'draft_id' => (string) $updated->registration_draft_id,
            'step' => $updated->step_code,
        ]);
    }

    public function validateDraftNationalCode(Request $request, int $draft): JsonResponse
    {
        $data = $request->validate(['national_code' => ['required', 'string', 'regex:/^[0-9۰-۹٠-٩]{10}$/']]);
        $record = RegistrationDraft::query()->findOrFail($draft);
        $assessment = $this->registrations->validateNationalIdForDraft($record, $data['national_code']);
        return ($assessment['valid'] ?? false) === true
            ? response()->json($assessment)
            : $this->nationalCodeError($assessment);
    }

    public function submitAgeEligibilityReport(Request $request, int $draft): JsonResponse
    {
        $data = $request->validate([
            'national_code' => ['required', 'string', 'regex:/^[0-9۰-۹٠-٩]{10}$/'],
            'birth_date' => ['required', 'string', 'max:10'],
        ]);
        $assessment = $this->registrations->validateNationalIdForDraft($draft, $data['national_code']);
        if (($assessment['code'] ?? null) !== 'national_id_area_ineligible') {
            return response()->json(['message' => 'فقط گزارش خطای تشخیص سن قابل ثبت است.'], 422);
        }
        $reportId = $this->registrations->createAgeEligibilityReport($draft, $data['national_code'], $data['birth_date']);
        return response()->json(['report_id' => $reportId, 'message' => 'گزارش برای بررسی ثبت شد.'], 201);
    }

    private function nationalCodeError(array $assessment): JsonResponse
    {
        $messages = [
            'invalid_national_code' => 'این کد ملی نادرست است لطفا کد ملی درست و واقعی وارد کنید',
            'national_code_already_registered' => 'این کد ملی قبلاً در اپ ثبت‌نام شده است.',
            'national_id_area_ineligible' => 'سامانه شما را زیر ۱۸ سال تشخیص داده است و شما مجاز به ثبت نام نیستید.',
        ];
        $code = (string) ($assessment['code'] ?? 'invalid_national_code');
        return response()->json([
            ...$assessment,
            'message' => $messages[$code] ?? $messages['invalid_national_code'],
        ], $code === 'national_code_already_registered' ? 409 : 422);
    }

    public function status(Request $request, int $draft): JsonResponse
    {
        $data = $request->validate([
            'telegram_link_nonce' => ['required', 'string', 'max:128'],
        ]);
        $record = RegistrationDraft::query()
            ->with(['telegramIdentities' => function ($query): void {
                $query->where('phone_verification_status', 'Verified');
            }])
            ->findOrFail($draft);

        if (
            $record->telegram_link_nonce_hash === null
            || $record->telegram_link_nonce_expires_at === null
            || $record->telegram_link_nonce_expires_at->isPast()
            || ! hash_equals(
                $record->telegram_link_nonce_hash,
                hash('sha256', $data['telegram_link_nonce'], true),
            )
        ) {
            return response()->json(['message' => 'لینک ثبت‌نام معتبر یا فعال نیست.'], 403);
        }

        $identity = $record->telegramIdentities->first();

        return response()->json([
            'draft_id' => (string) $record->registration_draft_id,
            'state' => $record->state_code,
            'step' => $record->step_code,
            'mobile_verified' => $record->mobile_verified_at !== null,
            'telegram_identity_id' => $identity?->telegram_identity_id
                ? (string) $identity->telegram_identity_id
                : null,
            'expires_at' => $record->expires_at?->toISOString(),
        ]);
    }

    public function complete(Request $request): JsonResponse
    {
        $data = $request->validate([
            'draft_id' => ['required', 'integer', 'min:1'],
            'telegram_identity_id' => ['required', 'integer', 'min:1'],
            'password' => ['required', 'string', 'min:8', 'max:255'],
        ]);

        $result = $this->registrations->completeRegistration(
            (int) $data['draft_id'],
            (int) $data['telegram_identity_id'],
            $data['password'],
        );

        return response()->json([
            'message' => 'ثبت‌نام با موفقیت تکمیل شد.',
            'user_id' => (string) $result['profile']->user_id,
        ], 201);
    }

    private function telegramStartUrl(string $nonce): ?string
    {
        $username = trim((string) config('services.telegram.bot_username'));

        return $username === '' ? null : "https://t.me/{$username}?start={$nonce}";
    }
}
