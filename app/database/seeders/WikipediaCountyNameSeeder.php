<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

/**
 * Align existing county display names with the current names on the
 * Persian Wikipedia county list while preserving county IDs and relations.
 * Counties without settlement data are deliberately not created here.
 */
class WikipediaCountyNameSeeder extends Seeder
{
    /** @var array<string, array<string, string>> */
    private const RENAMES = [
        'اصفهان' => [
            'بویین میاندشت' => 'بوئین میاندشت',
            'بو یین و میاندشت' => 'بوئین میاندشت',
            'نایین' => 'نائین',
        ],
        'خراسان جنوبی' => ['قاینات' => 'قائنات'],
        'سیستان و بلوچستان' => [
            'چاهبهار' => 'چابهار',
            'چاه بهار' => 'چابهار',
        ],
        'قزوین' => ['بویین زهرا' => 'بوئین زهرا'],
        'لرستان' => ['چگنی' => 'دوره'],
        'مازندران' => [
            'قایمشهر' => 'قائمشهر',
            'قایم شهر' => 'قائمشهر',
            'میاندورود' => 'میاندرود',
        ],
        'کرمان' => ['ارزوییه' => 'ارزوئیه'],
        'کهگیلویه و بویراحمد' => ['بهمیی' => 'بهمئی'],
        'گلستان' => [
            'علی آباد کتول' => 'علی‌آباد',
            'علی‌آباد کتول' => 'علی‌آباد',
            'علیابادکتول' => 'علی‌آباد',
        ],
        'گیلان' => ['طوالش' => 'تالش'],
    ];

    /** @var array<string, string> Wikipedia province name => stored name */
    private const PROVINCE_NAME_ALIASES = [
        'سیستان و بلوچستان' => 'سیستان وبلوچستان',
        'چهارمحال و بختیاری' => 'چهارمحال وبختیاری',
        'کهگیلویه و بویراحمد' => 'کهگیلویه وبویراحمد',
    ];

    public function run(): void
    {
        $updated = 0;

        DB::transaction(function () use (&$updated): void {
            foreach (self::RENAMES as $provinceName => $renames) {
                $provinceId = DB::table('provinces')
                    ->where('name_fa', self::PROVINCE_NAME_ALIASES[$provinceName] ?? $provinceName)
                    ->value('province_id');

                if ($provinceId === null) {
                    continue;
                }

                foreach ($renames as $oldName => $newName) {
                    $updated += DB::table('counties')
                        ->where('province_id', $provinceId)
                        ->where('name_fa', $oldName)
                        ->update(['name_fa' => $newName, 'updated_at' => now()]);
                }
            }
        });

        $this->command?->info("Updated {$updated} existing county names; county IDs and relations were preserved.");
    }
}
