<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('home_introduction_sections', function (Blueprint $table) {
            $table->id();
            $table->string('section_key', 40)->unique();
            $table->string('title', 160);
            $table->longText('body_text');
            $table->boolean('is_published')->default(false);
            $table->timestamps();
        });
        Schema::create('home_active_events', function (Blueprint $table) {
            $table->id();
            $table->string('kind', 20);
            $table->string('title', 255);
            $table->boolean('is_active')->default(true);
            $table->timestamps();
            $table->index(['kind', 'is_active']);
        });

        // The home activation workflow has four ordered states. Preserve the
        // currently configured state while replacing its lookup descriptions.
        DB::table('system_state_lookups')->upsert([
            ['state_code' => 1, 'state_name' => 'در حال کسب نصاب برای فعالسازی بخش همه پرسی', 'description' => 'Activation phase, waiting for initial threshold'],
            ['state_code' => 2, 'state_name' => 'بخش همه پرسی فعال است', 'description' => 'Referendum ready state'],
            ['state_code' => 3, 'state_name' => 'بخش های همه پرسی و انتخابات فعال است', 'description' => 'Referendum and election sections active'],
            ['state_code' => 4, 'state_name' => 'بخش های همه پرسی، انتخابات و استیضاح فعال هستند', 'description' => 'Referendum, election, and impeachment sections active'],
        ], ['state_code'], ['state_name', 'description']);
        // Map legacy rollout stages into the nearest enabled feature set.
        DB::table('system_states')->where('state_value', '>=', 5)
            ->update(['state_value' => 3, 'state_changed_at' => now()]);
        DB::table('system_state_lookups')->where('state_code', '>', 4)->delete();
        $countryId = DB::table('countries')->where('country_code', 364)->value('country_id');
        if ($countryId !== null) {
            DB::table('country_active_user_counters')->updateOrInsert(
                ['country_id' => $countryId], ['active_user_count' => DB::table('user_profiles')->where('is_active', true)->count()]
            );
            DB::table('system_states')->insertOrIgnore([
                'system_state_id' => 1, 'state_value' => 1, 'root_country_id' => $countryId,
                'activation_user_threshold' => 44000000, 'breathing_period_hours' => 24,
                'state_changed_at' => now(),
            ]);
        }
        if (DB::getDriverName() === 'mysql') {
            DB::statement('ALTER TABLE system_states DROP CHECK chk_system_state_value');
            DB::statement('ALTER TABLE system_states ADD CONSTRAINT chk_system_state_value CHECK (state_value between 1 and 4)');
        }
    }

    public function down(): void
    {
        if (DB::getDriverName() === 'mysql') {
            DB::statement('ALTER TABLE system_states DROP CHECK chk_system_state_value');
            DB::statement('ALTER TABLE system_states ADD CONSTRAINT chk_system_state_value CHECK (state_value between 1 and 7)');
        }
        DB::table('system_state_lookups')->upsert([
            ['state_code' => 1, 'state_name' => 'Activation phase', 'description' => 'Waiting for initial threshold'],
            ['state_code' => 2, 'state_name' => 'Referendum ready state', 'description' => null],
            ['state_code' => 3, 'state_name' => 'First Presidential Election', 'description' => null],
            ['state_code' => 4, 'state_name' => 'First Provincial/State Elections', 'description' => null],
            ['state_code' => 5, 'state_name' => 'First County/Governorship Elections', 'description' => null],
            ['state_code' => 6, 'state_name' => 'First Municipal Elections', 'description' => null],
            ['state_code' => 7, 'state_name' => 'System completely deployed/finalized', 'description' => null],
        ], ['state_code'], ['state_name', 'description']);
        DB::table('system_states')->where('state_value', 3)->update(['state_value' => 5, 'state_changed_at' => now()]);
        Schema::dropIfExists('home_active_events');
        Schema::dropIfExists('home_introduction_sections');
    }
};
