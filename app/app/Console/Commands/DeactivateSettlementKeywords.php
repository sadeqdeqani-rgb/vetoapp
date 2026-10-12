<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\File;
use Illuminate\Support\Str;
use RuntimeException;

class DeactivateSettlementKeywords extends Command
{
    protected $signature = 'geography:deactivate-settlement-keywords {--dry-run} {--apply} {--rollback=}';
    protected $description = 'Deactivate active settlement rows whose names contain any excluded non-settlement term.';

    private const TERMS = [
        'پادگان','ایستگاه','پایگاه','ستاد','برجک','شهرک','مجتمع','کارخانه','کارگاه','دامداری','آغل','مرتع',
        'موسسه','مرکز','کشت و صنعت','آموزش','ساختمان','اردوگاه','دکل','شیلات','معدن','پاسگاه','پلیس','مرغداری',
        'دهکده','ندامتگاه','آسایشگاه','هنرستان','گاوداری','بازرسی','پرورش','دانشکده','تولیدی','مستقل','قالیشویی',
        'معاینه فنی','مسجد','بازار','بیمارستان','پشتیبانی','سردخانه','تاسیسات','میدان','کوره','آموزشکده','تیپ',
        'گروهان','گردان','لشکر','لشگر','هنگ','مسکونی','برج','کشتارگاه','معاونت','پمپ بنزین','تیرچه','دانشگاه',
        'جایگاه','پارک','کشاورزی','سنگ شکن','پروار بندی','کشتی سازی','اقامتی','نفتی','دژبانی','سالمندان','تلمبه',
        'ناحیه','سنگبری','پبیست','تعاونی','طرح','منطقه','مزرعه','بلوک','قنات','امامزاده','نهالستان','چاه',
        'فرودگاه','پدافند','شرکت','موتور','زندان','راهدارخانه','قشلاق','ییلاق','گروه','سالن','سازمان','شهید',
        'ماسه شویی','مرغ','باغ','قدمگاه','پالایشگاه','نخلستان','احشام','مکانیزه','کاروانسرا','نزاجا','نهاجا',
        'خودکفایی','شماره','شهدا','بهشت','علوفه','ماسه','مزارع','گله داری','پیست','برنجکوبی','گلخانه','خوابگاه',
        'تلویزیون','دبیرستان','قهوه خانه','رستوران','چلوکبابی','پست برق','سیلندر','دامپروری','زیارتگاه','اسکله',
        'روغن کشی','پمپ','نمایشگاه','سیلو','تالار','قرار گاه','سایت',
    ];

    public function handle(): int
    {
        if ($this->option('rollback')) return $this->rollback((string) $this->option('rollback'));
        if ($this->option('apply') && $this->option('dry-run')) {
            $this->error('Choose either --dry-run or --apply.');
            return self::INVALID;
        }

        $cityKeys = $this->cityKeys();
        $rows = DB::table('settlements as s')
            ->join('counties as c', 'c.county_id', '=', 's.county_id')
            ->join('provinces as p', 'p.province_id', '=', 'c.province_id')
            ->select(['s.settlement_id', 's.name_fa', 's.is_active', 'c.name_fa as county_name', 'p.name_fa as province_name'])
            ->orderBy('s.settlement_id')->get();

        $termCounts = [];
        $ruleCounts = ['more_than_three_words' => 0, 'contains_number' => 0, 'contains_punctuation' => 0];
        $matches = [];
        $cityProtected = 0;
        foreach (self::TERMS as $term) $termCounts[$term] = 0;
        foreach ($rows as $row) {
            $geoKey = $this->geoKey((string) $row->province_name, (string) $row->county_name, (string) $row->name_fa);
            if (isset($cityKeys[$geoKey])) {
                $cityProtected++;
                continue;
            }
            $matchedTerms = [];
            $wordCount = preg_match_all('/[\p{L}\p{N}]+/u', (string) $row->name_fa);
            if ($wordCount !== false && $wordCount > 3) {
                $matchedTerms[] = 'RULE:more_than_three_words';
                $ruleCounts['more_than_three_words']++;
            }
            if (preg_match('/\p{N}/u', (string) $row->name_fa) === 1) {
                $matchedTerms[] = 'RULE:contains_number';
                $ruleCounts['contains_number']++;
            }
            if (preg_match('/[،,\/\.]/u', (string) $row->name_fa) === 1) {
                $matchedTerms[] = 'RULE:contains_punctuation';
                $ruleCounts['contains_punctuation']++;
            }
            foreach (self::TERMS as $term) {
                if ($this->containsWholeTerm((string) $row->name_fa, $term)) {
                    $termCounts[$term]++;
                    $matchedTerms[] = $term;
                }
            }
            if ($matchedTerms !== []) {
                $matches[] = [
                    'settlement_id' => (int) $row->settlement_id,
                    'province' => (string) $row->province_name,
                    'county' => (string) $row->county_name,
                    'name' => (string) $row->name_fa,
                    'was_active' => (bool) $row->is_active,
                    'matched_terms' => $matchedTerms,
                ];
            }
        }

        $active = array_values(array_filter($matches, fn ($r) => $r['was_active']));
        $inactive = count($matches) - count($active);
        $this->line(json_encode([
            'database' => DB::connection()->getDatabaseName(),
            'total_settlements' => $rows->count(),
            'official_city_rows_protected' => $cityProtected,
            'matching_rows_total' => count($matches),
            'matching_rows_active' => count($active),
            'matching_rows_already_inactive' => $inactive,
            'rule_hit_counts_overlap' => $ruleCounts,
            'term_hit_counts_overlap' => $termCounts,
            'active_sample' => array_slice($active, 0, 40),
        ], JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT));

        if (! $this->option('apply')) {
            $this->info('Dry run only; database was not changed.');
            return self::SUCCESS;
        }

        $runId = (string) Str::uuid();
        $directory = storage_path('app/geography-keyword-inactivation');
        File::ensureDirectoryExists($directory);
        $auditPath = $directory.'/'.$runId.'.json';
        $payload = ['run_id' => $runId, 'database' => DB::connection()->getDatabaseName(), 'created_at' => now()->toIso8601String(), 'rows' => $active];
        File::put($auditPath, json_encode($payload, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT));

        DB::transaction(function () use ($active): void {
            foreach (array_chunk(array_column($active, 'settlement_id'), 500) as $ids) {
                DB::table('settlements')->whereIn('settlement_id', $ids)->where('is_active', true)
                    ->update(['is_active' => false, 'updated_at' => now()]);
            }
        });
        $this->info('Inactive rows: '.count($active));
        $this->info('Rollback record: '.$auditPath);
        return self::SUCCESS;
    }

    private function rollback(string $runId): int
    {
        if (! preg_match('/^[0-9a-f-]{36}$/i', $runId)) {
            $this->error('Rollback value must be a run UUID.');
            return self::INVALID;
        }
        $path = storage_path('app/geography-keyword-inactivation/'.$runId.'.json');
        if (! File::exists($path)) {
            $this->error('Rollback record not found: '.$path);
            return self::FAILURE;
        }
        $audit = json_decode(File::get($path), true);
        if (! is_array($audit) || ($audit['database'] ?? null) !== DB::connection()->getDatabaseName()) {
            $this->error('Rollback record is invalid or belongs to another database.');
            return self::FAILURE;
        }
        $ids = array_column($audit['rows'] ?? [], 'settlement_id');
        DB::transaction(function () use ($ids): void {
            foreach (array_chunk($ids, 500) as $chunk) {
                DB::table('settlements')->whereIn('settlement_id', $chunk)->where('is_active', false)
                    ->update(['is_active' => true, 'updated_at' => now()]);
            }
        });
        $this->info('Reactivated '.count($ids).' rows from '.$runId.'.');
        return self::SUCCESS;
    }

    private function normalize(string $value): string
    {
        $value = strtr(trim($value), ['ي' => 'ی', 'ى' => 'ی', 'ك' => 'ک', 'آ' => 'ا', 'ـ' => '', "\u{200c}" => '', "\u{200f}" => '', "\u{200e}" => '']);
        $value = preg_replace('/[^\p{L}\p{N}]+/u', ' ', $value) ?? $value;
        return trim(preg_replace('/\s+/u', ' ', $value) ?? $value);
    }

    private function containsWholeTerm(string $name, string $term): bool
    {
        $name = $this->normalize($name);
        $term = $this->normalize($term);
        if ($name === '' || $term === '') return false;
        // Digits and punctuation are separators too: e.g. "پادگان02" still
        // contains the excluded term, while "سیلوانه" does not contain "سیلو".
        $pattern = '/(?<!\p{L})'.preg_quote($term, '/').'(?!\p{L})/u';
        return preg_match($pattern, $name) === 1;
    }

    private function geoKey(string $province, string $county, string $name): string
    {
        return implode("\0", [$this->normalizeGeo($province), $this->normalizeGeo($county), $this->normalizeGeo($name)]);
    }

    private function normalizeGeo(string $value): string
    {
        return str_replace(' ', '', $this->normalize($value));
    }

    private function cityKeys(): array
    {
        $path = database_path('seed_data/فهرست-شهرهای-ایران.md');
        if (! is_file($path)) throw new RuntimeException('Official city catalog not found: '.$path);
        $province = $county = null;
        $keys = [];
        foreach (file($path, FILE_IGNORE_NEW_LINES) ?: [] as $line) {
            $line = trim($line);
            if (str_starts_with($line, '## ')) { $province = trim(substr($line, 3)); $county = null; }
            elseif (str_starts_with($line, '### ')) $county = trim(substr($line, 4));
            elseif (str_starts_with($line, '- ') && $province !== null && $county !== null && ! str_starts_with($line, '- تعداد')) {
                $keys[$this->geoKey($province, $county, trim(substr($line, 2)))] = true;
            }
        }
        return $keys;
    }
}
