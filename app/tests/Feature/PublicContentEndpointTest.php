<?php

namespace Tests\Feature;

use App\Models\SystemIntroductionContent;
use App\Models\SystemIntroductionVideo;
use App\Models\SystemTermsContent;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class PublicContentEndpointTest extends TestCase
{
    use RefreshDatabase;

    public function test_public_endpoints_return_the_latest_published_active_content(): void
    {
        $oldIntroduction = SystemIntroductionContent::create([
            'version_number' => 1,
            'title' => 'معرفی قدیمی',
            'body_text' => 'متن قدیمی',
            'is_active' => true,
            'published_at' => now()->subDay(),
        ]);
        SystemIntroductionContent::create([
            'version_number' => 2,
            'title' => 'معرفی آینده',
            'body_text' => 'متن آینده',
            'is_active' => true,
            'published_at' => now()->addDay(),
        ]);
        $latestIntroduction = SystemIntroductionContent::create([
            'version_number' => 3,
            'title' => 'معرفی فعلی',
            'body_text' => 'متن فعلی',
            'is_active' => true,
            'published_at' => now()->subHour(),
        ]);
        SystemIntroductionContent::create([
            'version_number' => 4,
            'title' => 'معرفی غیرفعال',
            'body_text' => 'متن غیرفعال',
            'is_active' => false,
            'published_at' => now()->subMinute(),
        ]);

        $latestTerms = SystemTermsContent::create([
            'version_number' => 2,
            'title' => 'قوانین فعلی',
            'body_text' => 'متن قوانین',
            'is_active' => true,
            'published_at' => now()->subMinute(),
        ]);
        $latestVideo = SystemIntroductionVideo::create([
            'version_number' => 5,
            'title' => 'ویدئوی فعلی',
            'video_url' => 'https://example.com/current.mp4',
            'poster_url' => 'https://example.com/current.jpg',
            'duration_seconds' => 90,
            'is_active' => true,
            'published_at' => now()->subMinute(),
        ]);

        $this->getJson('/api/v1/content/introduction')
            ->assertOk()
            ->assertJsonPath('data.introduction_content_id', $latestIntroduction->getKey())
            ->assertJsonPath('data.title', 'معرفی فعلی');
        $this->getJson('/api/v1/content/terms')
            ->assertOk()
            ->assertJsonPath('data.terms_content_id', $latestTerms->getKey());
        $this->getJson('/api/v1/content/introduction-video')
            ->assertOk()
            ->assertJsonPath('data.introduction_video_id', $latestVideo->getKey())
            ->assertJsonPath('data.video_url', 'https://example.com/current.mp4');

        $this->assertNotSame($oldIntroduction->getKey(), $latestIntroduction->getKey());
    }

    public function test_public_endpoints_return_not_found_when_no_content_is_published(): void
    {
        SystemIntroductionContent::create([
            'version_number' => 1,
            'title' => 'پیش‌نویس',
            'body_text' => 'منتشر نشده',
            'is_active' => false,
        ]);

        $this->getJson('/api/v1/content/introduction')->assertNotFound();
        $this->getJson('/api/v1/content/terms')->assertNotFound();
        $this->getJson('/api/v1/content/introduction-video')->assertNotFound();
    }
}
