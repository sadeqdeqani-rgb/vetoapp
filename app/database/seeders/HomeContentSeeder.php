<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class HomeContentSeeder extends Seeder
{
    public function run(): void
    {
        $rows = [
            'goals' => ['اهداف وتواپ', 'وتواپ برای فراهم کردن امکان همه‌پرسی، انتخابات و استیضاح طراحی شده است.'],
            'identity' => ['مکانیسم احراز هویت', 'ثبت‌نام با شمارهٔ تلفن همراه و کد ملی انجام می‌شود. کد ملی از نظر ساختار، تکراری نبودن و سیاست‌های ثبت‌نام بررسی می‌شود.'],
            'activation' => ['نحوه فعال سازی سامانه', 'بخش همه‌پرسی پس از رسیدن شمار کاربران فعال به نصاب ۴۴ میلیون فعال می‌شود. فعال‌سازی بخش‌های بعدی با تغییر وضعیت توسط مدیر سامانه انجام می‌شود.'],
            'validation' => ['فرآیند اعتبارسنجی سامانه', 'سامانه یکتایی شمارهٔ تلفن همراه و کد ملی را در فرایند ثبت‌نام بررسی می‌کند و وضعیت کاربران فعال را در پایگاه داده نگه می‌دارد.'],
            'technical' => ['زیرساخت فنی', 'رابط کاربری با Flutter، API با Laravel و پایگاه داده با MySQL پیاده‌سازی شده است.'],
            'creators' => ['هویت سازندگان', 'صادق دهقانی و مجید قرقانی، سازندگان وتواپ هستند.'],
        ];
        foreach ($rows as $key => [$title, $body]) {
            DB::table('home_introduction_sections')->insertOrIgnore([
                'section_key' => $key, 'title' => $title, 'body_text' => $body,
                'is_published' => true, 'created_at' => now(), 'updated_at' => now(),
            ]);
        }
    }
}
