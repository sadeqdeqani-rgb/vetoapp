<?php

namespace Tests\Feature;

use App\Models\SystemIntroductionContent;
use App\Models\SystemIntroductionVideo;
use App\Models\SystemTermsContent;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class SystemContentSchemaTest extends TestCase
{
    use RefreshDatabase;

    public function test_system_content_entities_store_text_and_video_metadata(): void
    {
        $introduction = SystemIntroductionContent::create([
            'version_number' => 1,
            'title' => 'معرفی سامانه',
            'body_text' => 'متن معرفی سامانه',
        ]);
        $terms = SystemTermsContent::create([
            'version_number' => 1,
            'title' => 'قوانین و مقررات',
            'body_text' => 'متن قوانین',
        ]);
        $video = SystemIntroductionVideo::create([
            'version_number' => 1,
            'title' => 'فیلم معرفی سامانه',
            'video_url' => 'https://example.com/intro.mp4',
        ]);

        $this->assertDatabaseHas('system_introduction_contents', [
            'introduction_content_id' => $introduction->getKey(),
            'body_text' => 'متن معرفی سامانه',
        ]);
        $this->assertDatabaseHas('system_terms_contents', [
            'terms_content_id' => $terms->getKey(),
            'body_text' => 'متن قوانین',
        ]);
        $this->assertDatabaseHas('system_introduction_videos', [
            'introduction_video_id' => $video->getKey(),
            'video_url' => 'https://example.com/intro.mp4',
        ]);
    }

    public function test_published_scope_excludes_inactive_and_future_content(): void
    {
        SystemIntroductionContent::create([
            'version_number' => 1,
            'title' => 'قدیمی',
            'body_text' => 'فعال',
            'is_active' => true,
            'published_at' => now()->subMinute(),
        ]);
        SystemIntroductionContent::create([
            'version_number' => 2,
            'title' => 'آینده',
            'body_text' => 'هنوز منتشر نشده',
            'is_active' => true,
            'published_at' => now()->addMinute(),
        ]);
        SystemIntroductionContent::create([
            'version_number' => 3,
            'title' => 'غیرفعال',
            'body_text' => 'غیرفعال',
            'is_active' => false,
            'published_at' => now()->subMinute(),
        ]);

        $this->assertSame([1], SystemIntroductionContent::published()
            ->pluck('version_number')->all());
    }

    public function test_versions_are_unique_per_entity(): void
    {
        SystemTermsContent::create([
            'version_number' => 1,
            'title' => 'نسخه اول',
            'body_text' => 'متن',
        ]);

        $this->expectException(\Illuminate\Database\QueryException::class);

        SystemTermsContent::create([
            'version_number' => 1,
            'title' => 'نسخه تکراری',
            'body_text' => 'متن',
        ]);
    }
}
