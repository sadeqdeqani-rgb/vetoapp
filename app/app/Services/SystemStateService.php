<?php

namespace App\Services;

use Illuminate\Support\Facades\DB;

class SystemStateService
{
    public function activateReferendumAtThreshold(): void
    {
        DB::transaction(function (): void {
            $state = DB::table('system_states')
                ->where('system_state_id', 1)
                ->lockForUpdate()
                ->first();

            if ($state === null || (int) $state->state_value !== 1) {
                return;
            }

            $activeUsers = DB::table('user_profiles')->where('is_active', true)->count();
            if ($activeUsers < (int) $state->activation_user_threshold) {
                return;
            }

            $now = now();
            DB::table('system_states')->where('system_state_id', 1)->update([
                'state_value' => 2,
                'threshold_reached_at' => $state->threshold_reached_at ?? $now,
                'state_changed_at' => $now,
                'changed_by_admin_id' => null,
                'updated_at' => $now,
            ]);
        });
    }
}
