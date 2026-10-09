<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    private const AUDIT_TABLE = 'settlement_population_exclusion_states';

    public function up(): void
    {
        $sourcePath = database_path('seed_data/zero_population_database_targets_1395.tsv');
        if (! is_file($sourcePath)) {
            throw new \RuntimeException("Zero-population target data not found: {$sourcePath}");
        }
        if (Schema::hasTable(self::AUDIT_TABLE)) {
            throw new \RuntimeException('Settlement population exclusion audit table already exists.');
        }

        $targets = [];
        foreach (file($sourcePath, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) ?: [] as $index => $line) {
            if ($index === 0) {
                continue;
            }
            $columns = str_getcsv($line, "\t");
            if (count($columns) < 3) {
                continue;
            }
            $targets[$this->key($columns[0], $columns[1], $columns[2])] = true;
        }
        if ($targets === []) {
            throw new \RuntimeException('Zero-population target data contains no rows.');
        }

        $matches = [];
        DB::table('settlements as s')
            ->join('counties as c', 'c.county_id', '=', 's.county_id')
            ->join('provinces as p', 'p.province_id', '=', 'c.province_id')
            ->select([
                's.settlement_id',
                's.name_fa as settlement_name',
                's.is_active',
                'c.name_fa as county_name',
                'p.name_fa as province_name',
            ])
            ->orderBy('s.settlement_id')
            ->chunk(1000, function ($rows) use (&$matches, $targets): void {
                foreach ($rows as $row) {
                    if (! isset($targets[$this->key(
                        (string) $row->province_name,
                        (string) $row->county_name,
                        (string) $row->settlement_name,
                    )])) {
                        continue;
                    }
                    $matches[] = [
                        'settlement_id' => (int) $row->settlement_id,
                        'was_active' => (bool) $row->is_active,
                    ];
                }
            });

        if ($matches === []) {
            throw new \RuntimeException(
                'No database settlements matched the census target list; no settlement was changed.',
            );
        }

        Schema::create(self::AUDIT_TABLE, function (Blueprint $table): void {
            $table->engine = 'InnoDB';
            $table->unsignedInteger('settlement_id')->primary();
            $table->boolean('was_active');
            $table->dateTime('created_at')->useCurrent();
            $table->foreign('settlement_id')->references('settlement_id')->on('settlements');
        });

        DB::transaction(function () use ($matches): void {
            foreach (array_chunk($matches, 500) as $chunk) {
                DB::table(self::AUDIT_TABLE)->insert(array_map(
                    fn (array $row): array => [
                        'settlement_id' => $row['settlement_id'],
                        'was_active' => $row['was_active'],
                        'created_at' => now(),
                    ],
                    $chunk,
                ));
                DB::table('settlements')
                    ->whereIn('settlement_id', array_column($chunk, 'settlement_id'))
                    ->where('is_active', true)
                    ->update(['is_active' => false, 'updated_at' => now()]);
            }
        });
    }

    public function down(): void
    {
        if (! Schema::hasTable(self::AUDIT_TABLE)) {
            return;
        }

        DB::transaction(function (): void {
            DB::table(self::AUDIT_TABLE)
                ->orderBy('settlement_id')
                ->chunkById(500, function ($rows): void {
                    foreach ($rows as $row) {
                        DB::table('settlements')
                            ->where('settlement_id', $row->settlement_id)
                            ->update([
                                'is_active' => (bool) $row->was_active,
                                'updated_at' => now(),
                            ]);
                    }
                }, 'settlement_id');
        });

        Schema::dropIfExists(self::AUDIT_TABLE);
    }

    private function key(string $province, string $county, string $settlement): string
    {
        return implode("\0", array_map($this->normalize(...), [$province, $county, $settlement]));
    }

    private function normalize(string $value): string
    {
        $value = strtr(trim($value), [
            'ي' => 'ی', 'ى' => 'ی', 'ك' => 'ک',
            "\u{200c}" => ' ', "\u{200f}" => '',
        ]);

        return preg_replace('/\s+/u', ' ', $value) ?? $value;
    }
};
