<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class HomeStateSeeder extends Seeder
{
    public function run(): void
    {
        $countryId = DB::table('countries')->where('country_code', 364)->value('country_id');
        if ($countryId === null) return;
        DB::table('country_active_user_counters')->insertOrIgnore([
            'country_id' => $countryId, 'active_user_count' => 0,
        ]);
        // Never reset a transition already made by an administrator.
        DB::table('system_states')->insertOrIgnore([
            'system_state_id' => 1, 'state_value' => 1, 'root_country_id' => $countryId,
            'activation_user_threshold' => 44000000, 'breathing_period_hours' => 24,
            'state_changed_at' => now(),
        ]);
    }
}
