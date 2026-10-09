<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    private const AUDIT_TABLE = 'settlement_population_exclusion_states_v2';

    public function up(): void
    {
        $sourcePath = database_path('seed_data/zero_population_province_targets_1395.tsv');
        if (! is_file($sourcePath)) {
            throw new \RuntimeException("Zero-population province target data not found: {$sourcePath}");
        }
        if (Schema::hasTable(self::AUDIT_TABLE)) {
            throw new \RuntimeException('The province/name exclusion audit table already exists.');
        }

        $targets = [];
        foreach (file($sourcePath, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) ?: [] as $index => $line) {
            if ($index === 0) {
                continue;
            }
            $columns = str_getcsv($line, "\t");
            if (count($columns) < 2) {
                continue;
            }
            $targets[$this->key($columns[0], $columns[1])] = true;
        }
        if ($targets === []) {
            throw new \RuntimeException('The province/name target file contains no rows.');
        }

        // County names are intentionally omitted because the census is from
        // 1395 and current county boundaries differ. Ambiguous live matches
        // are left active unless exactly one settlement matches in a province.
        $matchesByTarget = [];
        DB::table('settlements as s')
            ->join('counties as c', 'c.county_id', '=', 's.county_id')
            ->join('provinces as p', 'p.province_id', '=', 'c.province_id')
            ->select([
                's.settlement_id',
                's.name_fa as settlement_name',
                's.is_active',
                'p.name_fa as province_name',
            ])
            ->orderBy('s.settlement_id')
            ->chunk(1000, function ($rows) use (&$matchesByTarget, $targets): void {
                foreach ($rows as $row) {
                    $key = $this->key(
                        (string) $row->province_name,
                        (string) $row->settlement_name,
                    );
                    if (! isset($targets[$key])) {
                        continue;
                    }
                    $matchesByTarget[$key][] = [
                        'settlement_id' => (int) $row->settlement_id,
                        'was_active' => (bool) $row->is_active,
                    ];
                }
            });

        $matches = [];
        foreach ($matchesByTarget as $rows) {
            if (count($rows) !== 1 || ! $rows[0]['was_active']) {
                continue;
            }
            $matches[] = $rows[0];
        }
        if ($matches === []) {
            throw new \RuntimeException(
                'No unique active province/name matches were found; no settlement was changed.',
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

    private function key(string $province, string $settlement): string
    {
        return implode("\0", array_map($this->normalize(...), [$province, $settlement]));
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
