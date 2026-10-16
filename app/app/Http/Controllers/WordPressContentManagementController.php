<?php

namespace App\Http\Controllers;

use App\Services\AdminAuditService;
use App\Services\WordPressContentService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use RuntimeException;

class WordPressContentManagementController extends Controller
{
    public function __construct(
        private readonly WordPressContentService $wordpress,
        private readonly AdminAuditService $audit,
    ) {}

    public function show(): JsonResponse
    {
        return $this->respond(fn () => $this->wordpress->content());
    }

    public function updateSettings(Request $request): JsonResponse
    {
        $data = $request->validate([
            'settings' => ['required', 'array', 'min:1', 'max:100'],
            'settings.*' => ['nullable', 'string', 'max:20000'],
        ]);

        return $this->respond(function () use ($request, $data): array {
            $before = $this->wordpress->content()['data']['settings'] ?? [];
            $result = $this->wordpress->updateSettings($data['settings']);
            $after = $result['data']['settings'] ?? $data['settings'];
            $this->audit->record(
                $request,
                $request->attributes->get('system_admin'),
                'update_wordpress_site_settings',
                'wordpress_options',
                'vetoapp_landing_options',
                is_array($before) ? $before : null,
                is_array($after) ? $after : null,
            );

            return $result;
        });
    }

    public function updatePage(Request $request, int $pageId): JsonResponse
    {
        $data = $request->validate([
            'title' => ['sometimes', 'required', 'string', 'max:255'],
            'content' => ['sometimes', 'string', 'max:200000'],
            'excerpt' => ['sometimes', 'nullable', 'string', 'max:20000'],
            'status' => ['sometimes', 'required', 'in:draft,publish'],
            'featured_media' => ['sometimes', 'nullable', 'integer', 'min:0'],
            'subtitle' => ['sometimes', 'nullable', 'string', 'max:2000'],
        ]);

        return $this->respond(function () use ($request, $pageId, $data): array {
            $pages = $this->wordpress->content()['data']['pages'] ?? [];
            $before = null;
            foreach (is_array($pages) ? $pages : [] as $candidate) {
                if ((int) ($candidate['id'] ?? 0) === $pageId) {
                    $before = array_intersect_key($candidate, array_flip([
                        'id', 'title', 'content', 'excerpt', 'status', 'subtitle', 'featured_media',
                    ]));
                    break;
                }
            }
            $result = $this->wordpress->updatePage($pageId, $data);
            $page = $result['data'] ?? [];
            $this->audit->record(
                $request,
                $request->attributes->get('system_admin'),
                'update_wordpress_page',
                'wordpress_pages',
                $pageId,
                $before,
                is_array($page) ? $page : $data,
            );

            return $result;
        });
    }

    public function updateCollectionItem(Request $request, string $type, int $itemId): JsonResponse
    {
        abort_unless(in_array($type, ['features', 'previews', 'faqs'], true), 404);
        $data = $request->validate([
            'title' => ['sometimes', 'required', 'string', 'max:255'],
            'content' => ['sometimes', 'nullable', 'string', 'max:100000'],
            'excerpt' => ['sometimes', 'nullable', 'string', 'max:20000'],
            'status' => ['sometimes', 'required', 'in:draft,publish'],
            'menu_order' => ['sometimes', 'integer', 'between:-10000,10000'],
            'featured_media' => ['sometimes', 'nullable', 'integer', 'min:0'],
            'icon' => ['sometimes', 'nullable', 'string', 'max:100'],
            'resource_url' => ['sometimes', 'nullable', 'url:https', 'max:2048'],
            'resource_label' => ['sometimes', 'nullable', 'string', 'max:255'],
        ]);

        return $this->respond(function () use ($request, $type, $itemId, $data): array {
            $all = $this->wordpress->content()['data']['collections'][$type] ?? [];
            $before = null;
            foreach (is_array($all) ? $all : [] as $candidate) {
                if ((int) ($candidate['id'] ?? 0) === $itemId) {
                    $before = array_intersect_key($candidate, array_flip([
                        'id', 'title', 'content', 'excerpt', 'status', 'menu_order',
                        'featured_media', 'icon', 'resource_url', 'resource_label',
                    ]));
                    break;
                }
            }
            $result = $this->wordpress->updateCollectionItem($type, $itemId, $data);
            $item = $result['data'] ?? [];
            $this->audit->record(
                $request,
                $request->attributes->get('system_admin'),
                'update_wordpress_'.$type,
                'wordpress_'.$type,
                $itemId,
                $before,
                is_array($item) ? $item : $data,
            );

            return $result;
        });
    }

    public function uploadMedia(Request $request): JsonResponse
    {
        $data = $request->validate([
            'file' => ['required', 'file', 'image', 'mimes:jpg,jpeg,png,webp,gif', 'max:10240'],
        ]);

        return $this->respond(function () use ($request, $data): array {
            $media = $this->wordpress->uploadMedia($data['file']);
            $item = $media['data'] ?? [];
            $this->audit->record(
                $request,
                $request->attributes->get('system_admin'),
                'upload_wordpress_image',
                'wordpress_media',
                is_array($item) ? ($item['id'] ?? null) : null,
                null,
                is_array($item) ? array_intersect_key($item, array_flip(['id', 'source_url', 'mime_type', 'alt_text'])) : null,
            );

            return $media;
        });
    }

    private function respond(callable $callback): JsonResponse
    {
        try {
            return response()->json($callback());
        } catch (RuntimeException $exception) {
            $status = in_array($exception->getCode(), [401, 403, 404, 409, 422, 503], true)
                ? $exception->getCode()
                : 502;

            return response()->json(['message' => $exception->getMessage()], $status);
        }
    }
}
