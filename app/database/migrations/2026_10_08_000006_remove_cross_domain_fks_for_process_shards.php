<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /** References that would cross from a process shard into the central user/geography database. */
    private const CROSS_DOMAIN_FOREIGN_KEYS = [
        'processes' => ['created_by_user_id' => ['user_profiles', 'user_id']],
        'support_participations' => [
            'country_id' => ['countries', 'country_id'],
            'province_id' => ['provinces', 'province_id'],
            'county_id' => ['counties', 'county_id'],
            'settlement_id' => ['settlements', 'settlement_id'],
        ],
        'digital_receipts' => ['beneficiary_user_account_id' => ['user_accounts', 'user_id']],
        'voter_participations' => [
            'country_id' => ['countries', 'country_id'],
            'province_id' => ['provinces', 'province_id'],
            'county_id' => ['counties', 'county_id'],
            'settlement_id' => ['settlements', 'settlement_id'],
        ],
        'ballot_box_entries' => [
            'country_id' => ['countries', 'country_id'],
            'province_id' => ['provinces', 'province_id'],
            'county_id' => ['counties', 'county_id'],
            'settlement_id' => ['settlements', 'settlement_id'],
        ],
        'notification_dispatches' => ['user_profile_id' => ['user_profiles', 'user_id']],
        'user_notifications' => ['user_profile_id' => ['user_profiles', 'user_id']],
    ];

    public function up(): void
    {
        foreach (self::CROSS_DOMAIN_FOREIGN_KEYS as $tableName => $columns) {
            if (! Schema::hasTable($tableName)) {
                continue;
            }

            $existing = DB::select(
                'SELECT CONSTRAINT_NAME, COLUMN_NAME FROM information_schema.KEY_COLUMN_USAGE '
                .'WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND REFERENCED_TABLE_NAME IS NOT NULL',
                [$tableName]
            );
            $foreignKeysByColumn = [];
            foreach ($existing as $foreignKey) {
                $foreignKeysByColumn[$foreignKey->COLUMN_NAME] = $foreignKey->CONSTRAINT_NAME;
            }
            $constraintsToDrop = [];
            foreach (array_keys($columns) as $column) {
                if (isset($foreignKeysByColumn[$column])) {
                    $constraintsToDrop[] = $foreignKeysByColumn[$column];
                }
            }
            foreach ($constraintsToDrop as $constraintName) {
                Schema::table($tableName, function (Blueprint $table) use ($constraintName): void {
                    $table->dropForeign($constraintName);
                });
            }
        }
    }

    public function down(): void
    {
        foreach (self::CROSS_DOMAIN_FOREIGN_KEYS as $tableName => $references) {
            if (! Schema::hasTable($tableName)) continue;
            Schema::table($tableName, function (Blueprint $table) use ($references): void {
                foreach ($references as $column => [$referencedTable, $referencedColumn]) {
                    $table->foreign($column)->references($referencedColumn)->on($referencedTable)
                        ->restrictOnDelete()->restrictOnUpdate();
                }
            });
        }
    }
};
