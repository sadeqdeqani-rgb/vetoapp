<?php

namespace App\Services;

use Illuminate\Http\Client\ConnectionException;
use Illuminate\Http\Client\PendingRequest;
use Illuminate\Http\Client\Response;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Http;
use RuntimeException;

class WordPressContentService
{
    private const API_PREFIX = '/wp-json/vetoapp-admin/v1';

    public function content(): array
    {
        return $this->request('get', self::API_PREFIX.'/content');
    }

    public function updateSettings(array $settings): array
    {
        return $this->request('put', self::API_PREFIX.'/settings', ['settings' => $settings]);
    }

    public function updatePage(int $pageId, array $data): array
    {
        return $this->request('patch', self::API_PREFIX.'/pages/'.$pageId, $data);
    }

    public function updateCollectionItem(string $type, int $itemId, array $data): array
    {
        return $this->request('patch', self::API_PREFIX.'/collections/'.$type.'/'.$itemId, $data);
    }

    public function uploadMedia(UploadedFile $file): array
    {
        $this->assertConfigured();
        $path = $file->getRealPath();
        if (! is_string($path) || ! is_file($path)) {
            throw new RuntimeException('فایل بارگذاری‌شده قابل خواندن نیست.');
        }
        $contents = file_get_contents($path);
        if (! is_string($contents)) {
            throw new RuntimeException('خواندن فایل تصویر انجام نشد.');
        }

        try {
            $response = $this->client()
                ->attach('file', $contents, $file->getClientOriginalName())
                ->post($this->url(self::API_PREFIX.'/media'));
        } catch (ConnectionException) {
            throw new RuntimeException('ارتباط با سرویس محتوای وردپرس برقرار نشد.');
        }

        return $this->decode($response);
    }

    private function request(string $method, string $path, ?array $data = null): array
    {
        $this->assertConfigured();

        try {
            $request = $this->client();
            $response = $method === 'get'
                ? $request->get($this->url($path))
                : $request->{$method}($this->url($path), $data ?? []);
        } catch (ConnectionException) {
            throw new RuntimeException('ارتباط با سرویس محتوای وردپرس برقرار نشد.');
        }

        return $this->decode($response);
    }

    private function decode(Response $response): array
    {
        $payload = $response->json();
        if (! $response->successful()) {
            $message = is_array($payload) && is_string($payload['message'] ?? null)
                ? $payload['message']
                : 'وردپرس درخواست مدیریت محتوا را نپذیرفت.';
            throw new RuntimeException($message, $response->status());
        }

        if (! is_array($payload)) {
            throw new RuntimeException('پاسخ سرویس محتوای وردپرس معتبر نیست.');
        }

        return $payload;
    }

    private function client(): PendingRequest
    {
        return Http::acceptJson()
            ->withBasicAuth(
                (string) config('services.wordpress_content.username'),
                (string) config('services.wordpress_content.application_password'),
            )
            ->timeout((int) config('services.wordpress_content.timeout', 20))
            ->withOptions(['allow_redirects' => false]);
    }

    private function url(string $path): string
    {
        return rtrim((string) config('services.wordpress_content.base_url'), '/').$path;
    }

    private function assertConfigured(): void
    {
        foreach (['base_url', 'username', 'application_password'] as $key) {
            if (! is_string(config('services.wordpress_content.'.$key))
                || trim((string) config('services.wordpress_content.'.$key)) === '') {
                throw new RuntimeException('اتصال مدیریت محتوای وردپرس هنوز پیکربندی نشده است.', 503);
            }
        }

        $scheme = parse_url((string) config('services.wordpress_content.base_url'), PHP_URL_SCHEME);
        if ($scheme !== 'https') {
            throw new RuntimeException('نشانی سرویس مدیریت وردپرس باید از HTTPS استفاده کند.', 503);
        }
    }
}
