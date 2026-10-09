<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('notifications', function (Blueprint $table): void {
            if (! Schema::hasColumn('notifications', 'audience_geographic_level_code')) {
                $table->unsignedTinyInteger('audience_geographic_level_code')->nullable()->after('audience_scope');
            }
            if (! Schema::hasColumn('notifications', 'audience_geographic_id')) {
                $table->unsignedBigInteger('audience_geographic_id')->nullable()->after('audience_geographic_level_code');
            }
            if (! Schema::hasColumn('notifications', 'source_event_key')) {
                $table->binary('source_event_key', 32, true)->nullable()->unique('uq_notification_event_key')->after('source_entity_id');
            }
        });

        if (DB::getDriverName() === 'mysql') {
            DB::statement("ALTER TABLE notifications ADD CONSTRAINT chk_notification_audience_geo_pair CHECK (
                (audience_geographic_level_code IS NULL AND audience_geographic_id IS NULL)
                OR (audience_geographic_level_code BETWEEN 1 AND 4 AND audience_geographic_id IS NOT NULL)
            )");
        }
        Schema::table('notifications', function (Blueprint $table): void {
            $table->index(['audience_geographic_level_code', 'audience_geographic_id', 'state', 'created_at'], 'idx_notification_audience_geo');
        });
    }

    public function down(): void
    {
        if (DB::getDriverName() === 'mysql') {
            DB::statement('ALTER TABLE notifications DROP CHECK chk_notification_audience_geo_pair');
        }
        Schema::table('notifications', function (Blueprint $table): void {
            $table->dropIndex('idx_notification_audience_geo');
            $table->dropUnique('uq_notification_event_key');
            $table->dropColumn(['audience_geographic_level_code', 'audience_geographic_id', 'source_event_key']);
        });
    }
};
