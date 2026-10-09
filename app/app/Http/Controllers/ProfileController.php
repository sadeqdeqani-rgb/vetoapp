<?php

namespace App\Http\Controllers;

use App\Models\AuthSession;
use App\Models\Settlement;
use App\Models\UserAccount;
use App\Models\UserProfile;
use App\Services\ProfilePolicyService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Validation\ValidationException;

class ProfileController extends Controller
{
    public function __construct(private readonly ProfilePolicyService $policies) {}

    public function show(Request $request): JsonResponse
    {
        /** @var UserProfile $profile */
        $profile = $request->attributes->get('user_profile');
        $profile->loadMissing('account');

        return response()->json([
            'data' => [
                'user_id' => (string) $profile->user_id,
                'phone_number' => $this->decrypt($profile->mobile_encrypted),
                'national_code' => $this->decrypt($profile->national_id_encrypted),
                'country_id' => $profile->country_id,
                'province_id' => $profile->province_id,
                'county_id' => $profile->county_id,
                'settlement_id' => $profile->settlement_id,
                'is_active' => (bool) $profile->is_active,
                'account_status' => $profile->account?->account_status,
            ],
        ]);
    }

    public function receipts(Request $request): JsonResponse
    {
        /** @var UserProfile $profile */
        $profile = $request->attributes->get('user_profile');
        $pagination = $request->validate([
            'page' => ['sometimes', 'integer', 'min:1'],
            'per_page' => ['sometimes', 'integer', 'between:1,50'],
        ]);
        $page = (int) ($pagination['page'] ?? 1);
        $perPage = (int) ($pagination['per_page'] ?? 20);
        $query = DB::table('digital_receipts')
            ->leftJoin('digital_receipt_vote_details as vote_detail', 'vote_detail.digital_receipt_id', '=', 'digital_receipts.digital_receipt_id')
            ->where('beneficiary_user_account_id', $profile->user_id);

        $total = (clone $query)->count();
        $items = $query->orderByDesc('issued_at')->orderByDesc('digital_receipt_id')
            ->offset(($page - 1) * $perPage)->limit($perPage)
            ->get([
                'digital_receipt_id', 'process_id', 'receipt_type_code', 'process_type_code',
                'event_title_snapshot', 'receipt_number', 'payload_version', 'receipt_hash',
                'signature_value', 'key_id', 'issued_at',
                'vote_detail.ballot_choice_key_snapshot', 'vote_detail.ballot_choice_label_snapshot',
            ])
            ->map(fn (object $receipt): array => [
                'receipt_id' => (string) $receipt->digital_receipt_id,
                'process_id' => (string) $receipt->process_id,
                'receipt_type_code' => $receipt->receipt_type_code,
                'process_type_code' => $receipt->process_type_code,
                'title' => $receipt->event_title_snapshot,
                'choice_key' => $receipt->ballot_choice_key_snapshot,
                'choice_label' => $receipt->ballot_choice_label_snapshot,
                'receipt_number' => $this->base64Url((string) $receipt->receipt_number),
                'payload_version' => (int) $receipt->payload_version,
                'receipt_hash' => $this->base64Url((string) $receipt->receipt_hash),
                'signature' => $this->base64Url(substr((string) $receipt->signature_value, 0, 64)),
                'key_id' => $receipt->key_id,
                'issued_at' => $receipt->issued_at,
            ])->all();

        return response()->json(['data' => [
            'items' => $items,
            'pagination' => ['page' => $page, 'per_page' => $perPage, 'total' => $total],
        ]]);
    }

    public function notifications(Request $request): JsonResponse
    {
        /** @var UserProfile $profile */
        $profile = $request->attributes->get('user_profile');
        $pagination = $request->validate([
            'page' => ['sometimes', 'integer', 'min:1'],
            'per_page' => ['sometimes', 'integer', 'between:1,50'],
        ]);
        $page = (int) ($pagination['page'] ?? 1);
        $perPage = (int) ($pagination['per_page'] ?? 20);
        $query = DB::table('notifications as n')
            ->leftJoin('user_notifications as un', function ($join) use ($profile): void {
                $join->on('un.notification_id', '=', 'n.notification_id')->where('un.user_profile_id', '=', $profile->user_id);
            })
            ->leftJoin('processes as p', 'p.process_id', '=', 'n.process_id')
            ->where('n.state', 'READY')
            ->where(function ($recipient) use ($profile): void {
                $recipient->whereNotNull('un.user_notification_id')
                    ->orWhere(function ($scope) use ($profile): void {
                        $scope->where('n.audience_scope', 'GEOGRAPHIC_DOMAIN')->where(function ($geo) use ($profile): void {
                            $geo->where(fn ($q) => $q->where('n.audience_geographic_level_code', 1)->where('n.audience_geographic_id', $profile->country_id))
                                ->orWhere(fn ($q) => $q->where('n.audience_geographic_level_code', 2)->where('n.audience_geographic_id', $profile->province_id))
                                ->orWhere(fn ($q) => $q->where('n.audience_geographic_level_code', 3)->where('n.audience_geographic_id', $profile->county_id))
                                ->orWhere(fn ($q) => $q->where('n.audience_geographic_level_code', 4)->where('n.audience_geographic_id', $profile->settlement_id));
                        });
                    });
            })
            ->where(fn ($visibility) => $visibility->whereNull('un.user_notification_id')->orWhere('un.is_archived', false));

        $total = (clone $query)->count('n.notification_id');
        $unread = (clone $query)->whereNull('un.read_at')->count('n.notification_id');
        $items = $query->orderByDesc('n.created_at')->orderByDesc('n.notification_id')
            ->offset(($page - 1) * $perPage)->limit($perPage)
            ->get([
                'un.user_notification_id', 'n.notification_id', 'un.read_at', 'n.created_at as delivered_at',
                'n.notification_type', 'n.payload_snapshot',
                'n.priority', 'p.title as process_title',
            ])
            ->map(function (object $notification): array {
                $payload = is_array($notification->payload_snapshot)
                    ? $notification->payload_snapshot
                    : (json_decode((string) $notification->payload_snapshot, true) ?: []);
                $title = $payload['title'] ?? $payload['headline'] ?? $this->notificationTitle((string) $notification->notification_type);
                $body = $payload['body'] ?? $payload['message'] ?? $payload['description'] ?? null;
                if (! is_string($body) || trim($body) === '') {
                    $body = is_string($notification->process_title) && $notification->process_title !== ''
                        ? 'این اعلان دربارهٔ «'.$notification->process_title.'» است.'
                        : 'اطلاعیه‌ای از سوی سامانه برای شما ثبت شده است.';
                }

                return [
                    'user_notification_id' => $notification->user_notification_id === null ? null : (string) $notification->user_notification_id,
                    'notification_id' => (string) $notification->notification_id,
                    'type' => $notification->notification_type,
                    'title' => is_string($title) ? $title : 'اطلاعیهٔ سامانه',
                    'body' => $body,
                    'process_title' => $notification->process_title,
                    'priority' => $notification->priority,
                    'is_read' => $notification->read_at !== null,
                    'delivered_at' => $notification->delivered_at,
                ];
            })->all();

        return response()->json(['data' => [
            'items' => $items,
            'unread_count' => $unread,
            'pagination' => ['page' => $page, 'per_page' => $perPage, 'total' => $total],
        ]]);
    }

    public function markNotificationRead(Request $request, int $notificationId): JsonResponse
    {
        /** @var UserProfile $profile */
        $profile = $request->attributes->get('user_profile');
        $notification = DB::table('notifications')->where('notification_id', $notificationId)->where('state', 'READY')->first([
            'notification_id', 'audience_scope', 'audience_geographic_level_code', 'audience_geographic_id',
        ]);
        abort_if($notification === null, 404);

        $personal = DB::table('user_notifications')->where('user_profile_id', $profile->user_id)
            ->where('notification_id', $notificationId)->exists();
        abort_unless($personal || $this->notificationMatchesProfile($notification, $profile), 404);

        $now = now();
        DB::table('user_notifications')->insertOrIgnore([
            'user_profile_id' => $profile->user_id,
            'notification_id' => $notificationId,
            'is_archived' => false,
            'read_at' => $now,
            'created_at' => $now,
        ]);
        DB::table('user_notifications')->where('user_profile_id', $profile->user_id)
            ->where('notification_id', $notificationId)->whereNull('read_at')->update(['read_at' => $now]);

        return response()->json(['message' => 'اعلان خوانده‌شده ثبت شد.']);
    }

    private function notificationMatchesProfile(object $notification, UserProfile $profile): bool
    {
        if ($notification->audience_scope !== 'GEOGRAPHIC_DOMAIN') return false;
        $profileGeo = match ((int) $notification->audience_geographic_level_code) {
            1 => (int) $profile->country_id,
            2 => (int) $profile->province_id,
            3 => (int) $profile->county_id,
            4 => (int) $profile->settlement_id,
            default => 0,
        };
        return $profileGeo > 0 && $profileGeo === (int) $notification->audience_geographic_id;
    }

    public function verifyPassword(Request $request): JsonResponse
    {
        $data = $request->validate(['current_password' => ['required', 'string', 'max:255']]);
        $this->assertPassword($request->attributes->get('user_profile'), $data['current_password']);

        return response()->json(['message' => 'رمز فعلی تأیید شد.']);
    }

    public function changePassword(Request $request): JsonResponse
    {
        $data = $request->validate([
            'current_password' => ['required', 'string', 'max:255'],
            'new_password' => ['required', 'string', 'min:8', 'max:255', 'confirmed'],
        ]);
        /** @var UserProfile $profile */
        $profile = $request->attributes->get('user_profile');
        $this->assertPassword($profile, $data['current_password']);
        if (Hash::check($data['new_password'], (string) $profile->account?->password_hash)) {
            throw ValidationException::withMessages(['new_password' => ['رمز جدید باید با رمز فعلی متفاوت باشد.']]);
        }

        UserAccount::query()->whereKey($profile->user_id)->update([
            'password_hash' => Hash::make($data['new_password']),
            'password_changed_at' => now(),
            'updated_at' => now(),
        ]);
        /** @var AuthSession $session */
        $session = $request->attributes->get('auth_session');
        AuthSession::query()->where('user_id', $profile->user_id)
            ->where('state', 'Active')->where('auth_session_id', '!=', $session->getKey())->update([
                'state' => 'Revoked', 'revoked_at' => now(), 'terminated_at' => now(),
                'terminal_reason' => 'password_changed', 'updated_at' => now(),
            ]);

        return response()->json(['message' => 'رمز عبور با موفقیت تغییر کرد.']);
    }

    public function geography(Request $request): JsonResponse
    {
        /** @var UserProfile $profile */
        $profile = $request->attributes->get('user_profile');
        $settlement = Settlement::query()->with('county.province.country')
            ->find($profile->settlement_id);
        $county = $settlement?->county;
        $province = $county?->province;

        return response()->json(['data' => [
            'country' => $province?->country?->name_fa,
            'country_id' => $province?->country?->country_id,
            'province' => $province?->name_fa,
            'province_id' => $province?->province_id,
            'county' => $county?->name_fa,
            'county_id' => $county?->county_id,
            'settlement' => $settlement?->name_fa,
            'settlement_id' => $profile->settlement_id,
            'policy' => $this->policies->geography($profile),
        ]]);
    }

    public function changeGeography(Request $request): JsonResponse
    {
        $data = $request->validate(['settlement_id' => ['required', 'integer', 'min:1']]);
        /** @var UserProfile $profile */
        $profile = $request->attributes->get('user_profile');

        return DB::transaction(function () use ($profile, $data): JsonResponse {
            $profile = UserProfile::query()->whereKey($profile->user_id)->lockForUpdate()->firstOrFail();
            $policy = $this->policies->geography($profile);
            if (! $policy['can_change']) {
                return response()->json(['message' => $policy['message'] ?? 'زمان مجاز تغییر حوزه هنوز فرا نرسیده است.', 'data' => $policy], 409);
            }
            $settlement = Settlement::query()->active()->with('county.province.country')
                ->findOrFail($data['settlement_id']);
            $county = $settlement->county;
            $province = $county?->province;
            $country = $province?->country;
            if (! $county?->is_active || ! $province?->is_active || ! $country?->is_active) {
                return response()->json(['message' => 'حوزهٔ انتخاب‌شده فعال نیست.'], 422);
            }
            if ($profile->settlement_id === $settlement->settlement_id) {
                return response()->json(['message' => 'حوزهٔ جدید با حوزهٔ فعلی یکسان است.'], 422);
            }
            $old = ['settlement_id' => $profile->settlement_id, 'county_id' => $profile->county_id,
                'province_id' => $profile->province_id, 'country_id' => $profile->country_id];
            $new = ['settlement_id' => $settlement->settlement_id, 'county_id' => $county->county_id,
                'province_id' => $province->province_id, 'country_id' => $country->country_id];
            $profile->forceFill([...$new, 'geo_updated_at' => now()])->save();
            DB::table('user_geo_change_logs')->insert([
                'user_id' => $profile->user_id,
                'old_settlement_id' => $old['settlement_id'], 'old_county_id' => $old['county_id'],
                'old_province_id' => $old['province_id'], 'old_country_id' => $old['country_id'],
                'new_settlement_id' => $new['settlement_id'], 'new_county_id' => $new['county_id'],
                'new_province_id' => $new['province_id'], 'new_country_id' => $new['country_id'],
                'change_source' => 'User', 'policy_id' => $policy['policy_id'], 'changed_at' => now(),
            ]);

            return response()->json(['message' => 'حوزهٔ جغرافیایی شما تغییر کرد.', 'data' => $this->policies->geography($profile)]);
        });
    }

    public function closurePolicy(Request $request): JsonResponse
    {
        return response()->json(['data' => $this->policies->closure($request->attributes->get('user_profile'))]);
    }

    public function close(Request $request): JsonResponse
    {
        $data = $request->validate([
            'password' => ['required', 'string', 'max:255'],
            'confirmed' => ['required', 'accepted'],
        ]);
        /** @var UserProfile $profile */
        $profile = $request->attributes->get('user_profile');

        return DB::transaction(function () use ($profile, $data): JsonResponse {
            $profile = UserProfile::query()->whereKey($profile->user_id)->lockForUpdate()->firstOrFail();
            $this->assertPassword($profile, $data['password']);
            if (! $profile->is_active || $profile->national_id_hash === null) {
                return response()->json(['message' => 'این حساب قابل بستن نیست.'], 409);
            }
            $policy = $this->policies->closure($profile, true);
            if (! $policy['can_close']) {
                return response()->json(['message' => $policy['message']], 409);
            }
            $now = now();
            DB::table('national_id_cooldown_ledgers')->updateOrInsert(
                ['national_id_hash' => $profile->national_id_hash],
                ['closure_count' => $policy['closure_count'], 'policy_id' => $policy['policy_id'],
                    'cooldown_hours' => $policy['penalty_hours'],
                    'cooldown_until' => \Illuminate\Support\Carbon::parse($policy['next_registration_at'])->format('Y-m-d H:i:s'),
                    'last_closed_at' => $now, 'updated_at' => $now]
            );
            UserAccount::query()->whereKey($profile->user_id)->update([
                'account_status' => 'Closed', 'updated_at' => $now,
            ]);
            $profile->forceFill(['is_active' => false])->save();
            AuthSession::query()->where('user_id', $profile->user_id)->where('state', 'Active')
                ->update(['state' => 'Revoked', 'revoked_at' => $now,
                    'terminated_at' => $now, 'terminal_reason' => 'force_revocation', 'updated_at' => $now]);

            return response()->json(['message' => 'حساب کاربری بسته شد.', 'data' => $policy]);
        });
    }

    private function assertPassword(UserProfile $profile, string $password): void
    {
        $key = 'profile-password:'.$profile->user_id;
        if (RateLimiter::tooManyAttempts($key, 5)) {
            throw ValidationException::withMessages(['password' => ['تلاش‌های ناموفق زیاد است. ۱۵ دقیقه بعد دوباره تلاش کنید.']]);
        }
        $profile->loadMissing('account');
        if ($profile->account?->account_status !== 'Active'
            || ! Hash::check($password, (string) $profile->account?->password_hash)) {
            RateLimiter::hit($key, 900);
            throw ValidationException::withMessages(['password' => ['رمز فعلی صحیح نیست.']]);
        }
        RateLimiter::clear($key);
    }

    private function decrypt(?string $value): ?string
    {
        if ($value === null || $value === '') return null;
        try {
            return Crypt::decryptString($value);
        } catch (\Throwable) {
            return null;
        }
    }

    private function base64Url(string $value): string
    {
        return rtrim(strtr(base64_encode($value), '+/', '-_'), '=');
    }

    private function notificationTitle(string $type): string
    {
        return match ($type) {
            'SUPPORT_THRESHOLD_MET' => 'موضوع به حد نصاب حمایت رسید',
            'WAITING_PERIOD_ELAPSED' => 'مرحلهٔ انتظار پایان یافت',
            'VOTING_OPENED' => 'رأی‌گیری آغاز شد',
            'VOTING_CLOSED', 'VOTING_PERIOD_ELAPSED' => 'رأی‌گیری پایان یافت',
            'RESULTS_PUBLISHED', 'PUBLICATION_DELAY_ELAPSED' => 'نتیجهٔ فرایند منتشر شد',
            default => 'اطلاعیهٔ سامانه',
        };
    }
}
