<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (DB::getDriverName() !== 'mysql') return;
        foreach ([
            'process_support_gate_events' => ['fk_support_gate_event_process'],
            'process_support_gate_assignments' => ['fk_support_gate_assignment_process', 'fk_support_gate_assignment_scope'],
        ] as $table => $constraints) {
            if (! Schema::hasTable($table)) continue;
            foreach ($constraints as $constraint) {
                $exists = DB::table('information_schema.REFERENTIAL_CONSTRAINTS')
                    ->where('CONSTRAINT_SCHEMA', DB::getDatabaseName())
                    ->where('TABLE_NAME', $table)->where('CONSTRAINT_NAME', $constraint)->exists();
                if ($exists) DB::statement("ALTER TABLE `{$table}` DROP FOREIGN KEY `{$constraint}`");
            }
        }
    }

    public function down(): void
    {
        // Cross-process foreign keys cannot be restored once process data is physically sharded.
    }
};
