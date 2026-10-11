<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    private const AUDIT = 'settlement_nonreal_exclusion_states';
    private const REPORT = 'settlement_nonreal_match_reports';
    private const EXPECTED_TARGETS = 4028;

    public function up(): void
    {
        $path = database_path('seed_data/nonreal_starred_settlements_1395.tsv');
        if (! is_file($path)) {
            throw new RuntimeException("Non-real settlement target list not found: {$path}");
        }
        if (Schema::hasTable(self::AUDIT) || Schema::hasTable(self::REPORT)) {
            throw new RuntimeException('Non-real settlement audit/report tables already exist.');
        }

        $targets = $this->readTargets($path);
        if (count($targets) !== self::EXPECTED_TARGETS) {
            throw new RuntimeException('Expected exactly 4,028 unique targets; found '.count($targets).'.');
        }

        Schema::create(self::AUDIT, function (Blueprint $table): void {
            $table->engine = 'InnoDB';
            $table->unsignedInteger('settlement_id')->primary();
            $table->boolean('was_active');
            $table->string('match_method', 32);
            $table->dateTime('created_at')->useCurrent();
            $table->foreign('settlement_id', 'fk_nonreal_state_settlement')
                ->references('settlement_id')->on('settlements')->restrictOnDelete();
        });

        Schema::create(self::REPORT, function (Blueprint $table): void {
            $table->engine = 'InnoDB';
            $table->bigIncrements('report_id');
            $table->string('province_name', 120);
            $table->string('county_name', 120);
            $table->string('settlement_name', 190);
            $table->text('source_census_codes')->nullable();
            $table->text('source_rows')->nullable();
            $table->text('filter_reasons')->nullable();
            $table->string('match_status', 24);
            $table->unsignedInteger('matched_settlement_id')->nullable();
            $table->string('match_method', 32)->nullable();
            $table->unsignedInteger('candidate_count')->default(0);
            $table->dateTime('created_at')->useCurrent();
            $table->index(['match_status', 'province_name'], 'idx_nonreal_report_status');
            $table->index('matched_settlement_id', 'idx_nonreal_report_settlement');
        });

        $live = DB::table('settlements as s')
            ->join('counties as c', 'c.county_id', '=', 's.county_id')
            ->join('provinces as p', 'p.province_id', '=', 'c.province_id')
            ->select(['s.settlement_id', 's.name_fa as settlement', 's.is_active', 'c.name_fa as county', 'p.name_fa as province'])
            ->orderBy('s.settlement_id')->get();

        $dbStrict = $this->index($live, fn ($r) => $this->key($r->province, $r->county, $r->settlement, false));
        $dbCompact = $this->index($live, fn ($r) => $this->key($r->province, $r->county, $r->settlement, true));
        $dbProvinceName = $this->index($live, fn ($r) => $this->key($r->province, '', $r->settlement, false));
        $dbProvinceNameCompact = $this->index($live, fn ($r) => $this->key($r->province, '', $r->settlement, true));

        $targetProvinceNameCounts = [];
        foreach ($targets as $target) {
            $key = $this->key($target['province_name'], '', $target['settlement_name'], false);
            $targetProvinceNameCounts[$key] = ($targetProvinceNameCounts[$key] ?? 0) + 1;
        }

        $resolved = [];
        foreach ($targets as $i => $target) {
            $strict = $this->key($target['province_name'], $target['county_name'], $target['settlement_name'], false);
            $strictCandidates = $dbStrict[$strict] ?? [];
            if (count($strictCandidates) > 1) {
                $resolved[$i] = ['target' => $target, 'status' => 'ambiguous', 'candidates' => $strictCandidates, 'method' => null];
                continue;
            }
            if (count($strictCandidates) === 1) {
                $resolved[$i] = ['target' => $target, 'status' => 'matched', 'candidates' => $strictCandidates, 'method' => 'exact_province_county_name'];
                continue;
            }

            $compact = $this->key($target['province_name'], $target['county_name'], $target['settlement_name'], true);
            $candidates = $dbCompact[$compact] ?? [];
            if (count($candidates) > 1) {
                $resolved[$i] = ['target' => $target, 'status' => 'ambiguous', 'candidates' => $candidates, 'method' => null];
                continue;
            }
            if (count($candidates) === 1) {
                $resolved[$i] = ['target' => $target, 'status' => 'matched', 'candidates' => $candidates, 'method' => 'normalized_province_county_name'];
                continue;
            }

            $pn = $this->key($target['province_name'], '', $target['settlement_name'], false);
            if (($targetProvinceNameCounts[$pn] ?? 0) !== 1) {
                $resolved[$i] = ['target' => $target, 'status' => 'ambiguous', 'candidates' => [], 'method' => null];
                continue;
            }
            $candidates = $dbProvinceName[$pn] ?? [];
            if (count($candidates) === 0) {
                $pnCompact = $this->key($target['province_name'], '', $target['settlement_name'], true);
                $candidates = $dbProvinceNameCompact[$pnCompact] ?? [];
                $method = 'normalized_unique_province_name';
            } else {
                $method = 'unique_province_name';
            }
            $resolved[$i] = [
                'target' => $target,
                'status' => count($candidates) === 1 ? 'matched' : (count($candidates) > 1 ? 'ambiguous' : 'unmatched'),
                'candidates' => $candidates,
                'method' => count($candidates) === 1 ? $method : null,
            ];
        }

        // Guard against two source rows resolving to one live settlement.
        $byLiveId = [];
        foreach ($resolved as $i => $item) {
            if ($item['status'] === 'matched') $byLiveId[(int) $item['candidates'][0]->settlement_id][] = $i;
        }
        foreach ($byLiveId as $indexes) {
            if (count($indexes) > 1) {
                foreach ($indexes as $i) {
                    $resolved[$i]['status'] = 'ambiguous';
                    $resolved[$i]['method'] = null;
                    $resolved[$i]['candidates'] = array_merge(...array_map(fn ($j) => $resolved[$j]['candidates'], $indexes));
                }
            }
        }

        DB::transaction(function () use ($resolved): void {
            $reports = [];
            $audit = [];
            $deactivate = [];
            foreach ($resolved as $item) {
                $target = $item['target'];
                $match = $item['status'] === 'matched' ? $item['candidates'][0] : null;
                $reports[] = [
                    'province_name' => $target['province_name'], 'county_name' => $target['county_name'],
                    'settlement_name' => $target['settlement_name'], 'source_census_codes' => $target['source_census_codes'],
                    'source_rows' => $target['source_rows'], 'filter_reasons' => $target['filter_reasons'],
                    'match_status' => $item['status'], 'matched_settlement_id' => $match ? (int) $match->settlement_id : null,
                    'match_method' => $match ? $item['method'] : null, 'candidate_count' => count($item['candidates']), 'created_at' => now(),
                ];
                if ($match) {
                    $id = (int) $match->settlement_id;
                    $audit[] = ['settlement_id' => $id, 'was_active' => (bool) $match->is_active, 'match_method' => $item['method'], 'created_at' => now()];
                    if ((bool) $match->is_active) $deactivate[] = $id;
                }
            }
            foreach (array_chunk($reports, 300) as $chunk) DB::table(self::REPORT)->insert($chunk);
            foreach (array_chunk($audit, 500) as $chunk) DB::table(self::AUDIT)->insert($chunk);
            foreach (array_chunk($deactivate, 500) as $chunk) {
                DB::table('settlements')->whereIn('settlement_id', $chunk)->where('is_active', true)
                    ->update(['is_active' => false, 'updated_at' => now()]);
            }
        });
    }

    private function readTargets(string $path): array
    {
        $lines = file($path, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) ?: [];
        $targets = [];
        foreach ($lines as $index => $line) {
            if ($index === 0) continue;
            $columns = str_getcsv($line, "\t");
            if (count($columns) < 6) throw new RuntimeException('Malformed target TSV row '.($index + 1).'.');
            $key = $this->key($columns[0], $columns[1], $columns[2], false);
            if (isset($targets[$key])) throw new RuntimeException('Duplicate normalized target in TSV row '.($index + 1).'.');
            $targets[$key] = [
                'province_name' => $columns[0], 'county_name' => $columns[1], 'settlement_name' => $columns[2],
                'source_census_codes' => $columns[3] ?: null, 'source_rows' => $columns[4] ?: null, 'filter_reasons' => $columns[5] ?: null,
            ];
        }
        return array_values($targets);
    }

    private function index(iterable $rows, callable $keyFn): array
    {
        $result = [];
        foreach ($rows as $row) $result[$keyFn($row)][] = $row;
        return $result;
    }

    private function key(string $province, string $county, string $settlement, bool $compact): string
    {
        return implode("\0", [$this->normalize($province, $compact), $this->normalize($county, $compact), $this->normalize($settlement, $compact)]);
    }

    private function normalize(string $value, bool $compact): string
    {
        $value = mb_strtolower(trim($value), 'UTF-8');
        $value = strtr($value, ['ي' => 'ی', 'ى' => 'ی', 'ك' => 'ک', 'أ' => 'ا', 'إ' => 'ا', 'آ' => 'ا', 'ۀ' => 'ه', 'ة' => 'ه', 'ؤ' => 'و', "\u{200f}" => '', "\u{200e}" => '']);
        $value = str_replace("\u{200c}", ' ', $value);
        $value = trim(preg_replace('/\s+/u', ' ', $value) ?? $value);
        return $compact ? str_replace(' ', '', $value) : $value;
    }

    public function down(): void
    {
        if (! Schema::hasTable(self::REPORT) || ! Schema::hasTable(self::AUDIT)) return;
        DB::transaction(function (): void {
            DB::table(self::AUDIT)->orderBy('settlement_id')->chunkById(500, function ($rows): void {
                foreach ($rows as $row) DB::table('settlements')->where('settlement_id', $row->settlement_id)
                    ->update(['is_active' => (bool) $row->was_active, 'updated_at' => now()]);
            }, 'settlement_id');
        });
        Schema::dropIfExists(self::REPORT);
        Schema::dropIfExists(self::AUDIT);
    }
};
