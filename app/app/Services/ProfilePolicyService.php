<?php

namespace App\Services;

use App\Models\AccountClosurePenaltyPolicy;
use App\Models\GeoCooldownPolicy;
use App\Models\UserProfile;
use Illuminate\Support\Facades\DB;

class ProfilePolicyService
{
    public function geography(UserProfile $profile): array
    {
        $now = now();
        $changes = DB::table('user_geo_change_logs')->where('user_id', $profile->user_id);
        $changeCount = (clone $changes)->count();
        $activePolicies = GeoCooldownPolicy::query()
            ->where('is_active', true)
            ->where('effective_from', '<=', $now)
            ->where(fn ($query) => $query->whereNull('effective_to')->orWhere('effective_to', '>', $now));
        $policy = (clone $activePolicies)
            ->where('policy_code', 'geo_reassignment_trial')
            ->orderByDesc('policy_id')
            ->first() ?? $activePolicies
            ->where('policy_stage', '<=', $changeCount + 1)
            ->orderByDesc('policy_stage')
            ->first();

        if ($policy === null) {
            return ['can_change' => false, 'message' => 'سیاست فعال تغییر حوزه تعریف نشده است.'];
        }

        $lastChange = (clone $changes)->orderByDesc('changed_at')->first();
        $lastAt = $lastChange === null
            ? ($profile->initial_geo_selected_at ?? $profile->geo_updated_at)
            : \Illuminate\Support\Carbon::parse($lastChange->changed_at);
        $nextAt = $lastAt?->copy()->addDays($policy->cooldown_days);

        if ($policy->max_changes_allowed !== null && $policy->window_days !== null) {
            $windowStart = $now->copy()->subDays($policy->window_days);
            $recent = (clone $changes)->where('changed_at', '>=', $windowStart)->orderBy('changed_at')->get();
            if ($policy->max_changes_allowed === 0) {
                return [
                    'can_change' => false,
                    'policy_name' => $policy->policy_name,
                    'message' => 'تغییر حوزه بر اساس سیاست فعال مجاز نیست.',
                ];
            }
            if ($recent->count() >= $policy->max_changes_allowed) {
                $slot = $recent[$recent->count() - $policy->max_changes_allowed];
                $windowEnd = \Illuminate\Support\Carbon::parse($slot->changed_at)->addDays($policy->window_days);
                if ($nextAt === null || $windowEnd->greaterThan($nextAt)) {
                    $nextAt = $windowEnd;
                }
            }
        }

        return [
            'can_change' => $nextAt === null || $now->greaterThanOrEqualTo($nextAt),
            'next_change_at' => $nextAt?->toISOString(),
            'cooldown_days' => $policy->cooldown_days,
            'policy_name' => $policy->policy_name,
            'policy_id' => $policy->policy_id,
            'change_count' => $changeCount,
        ];
    }

    public function closure(UserProfile $profile, bool $lock = false): array
    {
        $now = now();
        $ledger = DB::table('national_id_cooldown_ledgers')
            ->where('national_id_hash', $profile->national_id_hash);
        if ($lock) {
            $ledger->lockForUpdate();
        }
        $record = $ledger->first();
        $count = (int) ($record->closure_count ?? 0) + 1;
        $activePolicies = AccountClosurePenaltyPolicy::query()
            ->where('is_active', true)
            ->where('trigger_scope', 'account_closure')
            ->where('effective_from', '<=', $now)
            ->where(fn ($query) => $query->whereNull('effective_to')->orWhere('effective_to', '>', $now));
        $policy = (clone $activePolicies)
            ->where('policy_code', 'account_closure_trial')
            ->orderByDesc('policy_id')
            ->first() ?? $activePolicies
            ->where('penalty_stage', '<=', $count)
            ->orderByDesc('penalty_stage')
            ->first();

        if ($policy === null) {
            return ['can_close' => false, 'message' => 'سیاست فعال بستن حساب تعریف نشده است.'];
        }

        return [
            'can_close' => true,
            'policy_id' => $policy->policy_id,
            'policy_name' => $policy->policy_name,
            'closure_count' => min($count, 255),
            'penalty_hours' => $policy->penalty_hours,
            'next_registration_at' => $now->copy()->addHours($policy->penalty_hours)->toISOString(),
        ];
    }
}
