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
            'national_code' => ['required', 'string'],
            'settlement_id' => ['required', 'integer', 'min:1'],
        ]);

        $updated = $this->registrations->selectNationalIdAndSettlement(
            RegistrationDraft::query()->findOrFail($draft),
            $data['national_code'],
            (int) $data['settlement_id'],
        );

        return response()->json([
            'draft_id' => (string) $updated->registration_draft_id,
            'step' => $updated->step_code,
        ]);
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
