<?php

namespace App\Http\Controllers;

use App\Models\Country;
use App\Models\County;
use App\Models\Province;
use App\Models\Settlement;
use App\Models\SystemIntroductionContent;
use App\Models\SystemIntroductionVideo;
use App\Models\SystemTermsContent;
use App\Services\AdminAuditService;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class AdminManagementController extends Controller
{
    public function __construct(private readonly AdminAuditService $audit)
    {
    }

    public function countries(): JsonResponse
    {
        return response()->json(Country::query()->orderBy('name_fa')->get());
    }

    public function introduction(): JsonResponse
    {
        return response()->json([
            'data' => SystemIntroductionContent::query()
                ->orderByDesc('version_number')
                ->paginate(20),
        ]);
    }

    public function storeIntroduction(Request $request): JsonResponse
    {
        $data = $request->validate([
            'version_number' => ['required', 'integer', 'min:1', 'unique:system_introduction_contents,version_number'],
            'title' => ['required', 'string', 'max:255'],
            'body_text' => ['required', 'string'],
            'is_active' => ['sometimes', 'boolean'],
            'published_at' => ['nullable', 'date'],
        ]);

        $content = DB::transaction(function () use ($request, $data): SystemIntroductionContent {
            $content = SystemIntroductionContent::create($data);
            if ($content->is_active) {
                $this->deactivateOtherContent(SystemIntroductionContent::class, $content->getKey());
            }
            $this->audit->record(
                $request,
                $this->admin($request),
                'create_system_introduction',
                'system_introduction_contents',
                $content->getKey(),
                null,
                $content->toArray(),
            );

            return $content;
        });

        return response()->json(['data' => $content], 201);
    }

    public function updateIntroduction(Request $request, int $id): JsonResponse
    {
        $content = SystemIntroductionContent::query()->findOrFail($id);
        $data = $request->validate([
            'title' => ['sometimes', 'string', 'max:255'],
            'body_text' => ['sometimes', 'string'],
            'is_active' => ['sometimes', 'boolean'],
            'published_at' => ['nullable', 'date'],
        ]);
        $before = $content->toArray();

        DB::transaction(function () use ($request, $content, $data, $before): void {
            $content->update($data);
            if ($content->is_active) {
                $this->deactivateOtherContent(SystemIntroductionContent::class, $content->getKey());
            }
            $this->audit->record($request, $this->admin($request), 'update_system_introduction', 'system_introduction_contents', $content->getKey(), $before, $content->fresh()->toArray());
        });

        return response()->json(['data' => $content->fresh()]);
    }

    public function publishIntroduction(Request $request, int $id): JsonResponse
    {
        return response()->json([
            'data' => $this->publishContent($request, SystemIntroductionContent::class, $id, 'system_introduction_contents', 'publish_system_introduction'),
        ]);
    }

    public function terms(): JsonResponse
    {
        return response()->json([
            'data' => SystemTermsContent::query()
                ->orderByDesc('version_number')
                ->paginate(20),
        ]);
    }

    public function storeTerms(Request $request): JsonResponse
    {
        $data = $request->validate([
            'version_number' => ['required', 'integer', 'min:1', 'unique:system_terms_contents,version_number'],
            'title' => ['required', 'string', 'max:255'],
            'body_text' => ['required', 'string'],
            'is_active' => ['sometimes', 'boolean'],
            'published_at' => ['nullable', 'date'],
        ]);

        $content = DB::transaction(function () use ($request, $data): SystemTermsContent {
            $content = SystemTermsContent::create($data);
            if ($content->is_active) {
                $this->deactivateOtherContent(SystemTermsContent::class, $content->getKey());
            }
            $this->audit->record($request, $this->admin($request), 'create_system_terms', 'system_terms_contents', $content->getKey(), null, $content->toArray());

            return $content;
        });

        return response()->json(['data' => $content], 201);
    }

    public function updateTerms(Request $request, int $id): JsonResponse
    {
        $content = SystemTermsContent::query()->findOrFail($id);
        $data = $request->validate([
            'title' => ['sometimes', 'string', 'max:255'],
            'body_text' => ['sometimes', 'string'],
            'is_active' => ['sometimes', 'boolean'],
            'published_at' => ['nullable', 'date'],
        ]);
        $before = $content->toArray();

        DB::transaction(function () use ($request, $content, $data, $before): void {
            $content->update($data);
            if ($content->is_active) {
                $this->deactivateOtherContent(SystemTermsContent::class, $content->getKey());
            }
            $this->audit->record($request, $this->admin($request), 'update_system_terms', 'system_terms_contents', $content->getKey(), $before, $content->fresh()->toArray());
        });

        return response()->json(['data' => $content->fresh()]);
    }

    public function publishTerms(Request $request, int $id): JsonResponse
    {
        return response()->json([
            'data' => $this->publishContent($request, SystemTermsContent::class, $id, 'system_terms_contents', 'publish_system_terms'),
        ]);
    }

    public function videos(): JsonResponse
    {
        return response()->json([
            'data' => SystemIntroductionVideo::query()
                ->orderByDesc('version_number')
                ->paginate(20),
        ]);
    }

    public function storeVideo(Request $request): JsonResponse
    {
        $data = $request->validate([
            'version_number' => ['required', 'integer', 'min:1', 'unique:system_introduction_videos,version_number'],
            'title' => ['required', 'string', 'max:255'],
            'video_url' => ['required', 'url:https', 'max:2048'],
            'poster_url' => ['nullable', 'url:https', 'max:2048'],
            'duration_seconds' => ['nullable', 'integer', 'min:0'],
            'is_active' => ['sometimes', 'boolean'],
            'published_at' => ['nullable', 'date'],
        ]);

        $video = DB::transaction(function () use ($request, $data): SystemIntroductionVideo {
            $video = SystemIntroductionVideo::create($data);
            if ($video->is_active) {
                $this->deactivateOtherContent(SystemIntroductionVideo::class, $video->getKey());
            }
            $this->audit->record($request, $this->admin($request), 'create_system_introduction_video', 'system_introduction_videos', $video->getKey(), null, $video->toArray());

            return $video;
        });

        return response()->json(['data' => $video], 201);
    }

    public function updateVideo(Request $request, int $id): JsonResponse
    {
        $video = SystemIntroductionVideo::query()->findOrFail($id);
        $data = $request->validate([
            'title' => ['sometimes', 'string', 'max:255'],
            'video_url' => ['sometimes', 'url:https', 'max:2048'],
            'poster_url' => ['nullable', 'url:https', 'max:2048'],
            'duration_seconds' => ['nullable', 'integer', 'min:0'],
            'is_active' => ['sometimes', 'boolean'],
            'published_at' => ['nullable', 'date'],
        ]);
        $before = $video->toArray();

        DB::transaction(function () use ($request, $video, $data, $before): void {
            $video->update($data);
            if ($video->is_active) {
                $this->deactivateOtherContent(SystemIntroductionVideo::class, $video->getKey());
            }
            $this->audit->record($request, $this->admin($request), 'update_system_introduction_video', 'system_introduction_videos', $video->getKey(), $before, $video->fresh()->toArray());
        });

        return response()->json(['data' => $video->fresh()]);
    }

    public function publishVideo(Request $request, int $id): JsonResponse
    {
        return response()->json([
            'data' => $this->publishContent($request, SystemIntroductionVideo::class, $id, 'system_introduction_videos', 'publish_system_introduction_video'),
        ]);
    }

    public function provinces(Request $request): JsonResponse
    {
        return $this->geoList($request, Province::class, ['country_id', 'province_code', 'name_fa', 'is_active']);
    }

    public function storeProvince(Request $request): JsonResponse
    {
        $data = $request->validate([
            'country_id' => ['required', 'integer', 'exists:countries,country_id'],
            'province_code' => ['required', 'integer', 'min:1', 'unique:provinces,province_code'],
            'name_fa' => ['required', 'string', 'max:100'],
            'is_active' => ['sometimes', 'boolean'],
        ]);

        return $this->storeGeo($request, Province::class, $data, 'provinces');
    }

    public function updateProvince(Request $request, int $id): JsonResponse
    {
        return $this->updateGeo($request, Province::class, $id, [
            'country_id' => ['sometimes', 'integer', 'exists:countries,country_id'],
            'province_code' => ['sometimes', 'integer', 'min:1', "unique:provinces,province_code,{$id},province_id"],
            'name_fa' => ['sometimes', 'string', 'max:100'],
            'is_active' => ['sometimes', 'boolean'],
        ], 'provinces');
    }

    public function counties(Request $request): JsonResponse
    {
        $query = County::query()->with('province')->orderBy('name_fa');
        if ($request->filled('province_id')) {
            $query->where('province_id', $request->integer('province_id'));
        }

        return response()->json($query->paginate(50));
    }

    public function storeCounty(Request $request): JsonResponse
    {
        $data = $request->validate([
            'province_id' => ['required', 'integer', 'exists:provinces,province_id'],
            'county_code' => ['required', 'integer', 'min:1', 'unique:counties,county_code'],
            'name_fa' => ['required', 'string', 'max:100'],
            'is_active' => ['sometimes', 'boolean'],
        ]);

        return $this->storeGeo($request, County::class, $data, 'counties');
    }

    public function updateCounty(Request $request, int $id): JsonResponse
    {
        return $this->updateGeo($request, County::class, $id, [
            'province_id' => ['sometimes', 'integer', 'exists:provinces,province_id'],
            'county_code' => ['sometimes', 'integer', 'min:1', "unique:counties,county_code,{$id},county_id"],
            'name_fa' => ['sometimes', 'string', 'max:100'],
            'is_active' => ['sometimes', 'boolean'],
        ], 'counties');
    }

    public function settlements(Request $request): JsonResponse
    {
        $query = Settlement::query()->with('county.province')->orderBy('name_fa');
        if ($request->filled('county_id')) {
            $query->where('county_id', $request->integer('county_id'));
        }

        return response()->json($query->paginate(50));
    }

    public function storeSettlement(Request $request): JsonResponse
    {
        $data = $request->validate([
            'county_id' => ['required', 'integer', 'exists:counties,county_id'],
            'settlement_code' => ['required', 'integer', 'min:1', 'unique:settlements,settlement_code'],
            'name_fa' => ['required', 'string', 'max:100'],
            'is_active' => ['sometimes', 'boolean'],
        ]);

        return $this->storeGeo($request, Settlement::class, $data, 'settlements');
    }

    public function updateSettlement(Request $request, int $id): JsonResponse
    {
        return $this->updateGeo($request, Settlement::class, $id, [
            'county_id' => ['sometimes', 'integer', 'exists:counties,county_id'],
            'settlement_code' => ['sometimes', 'integer', 'min:1', "unique:settlements,settlement_code,{$id},settlement_id"],
            'name_fa' => ['sometimes', 'string', 'max:100'],
            'is_active' => ['sometimes', 'boolean'],
        ], 'settlements');
    }

    public function nationalIdRanges(Request $request): JsonResponse
    {
        $query = DB::table('national_id_area_eligibilities')
            ->orderBy('national_id_prefix_3');
        if ($request->filled('prefix')) {
            $query->where('national_id_prefix_3', $request->integer('prefix'));
        }

        return response()->json($query->paginate(100));
    }

    public function storeNationalIdRange(Request $request, int $prefix): JsonResponse
    {
        $data = $request->validate([
            'first_range_from' => ['required', 'integer', 'between:0,999', 'lte:first_range_to'],
            'first_range_to' => ['required', 'integer', 'between:0,999'],
            'second_range_from' => ['required', 'integer', 'between:0,999', 'lte:second_range_to'],
            'second_range_to' => ['required', 'integer', 'between:0,999'],
        ]);
        abort_if($prefix < 0 || $prefix > 999, 422, 'Prefix باید بین 000 و 999 باشد.');

        $before = DB::table('national_id_area_eligibilities')
            ->where('national_id_prefix_3', $prefix)
            ->first();
        DB::table('national_id_area_eligibilities')->updateOrInsert(
            ['national_id_prefix_3' => $prefix],
            [...$data, 'updated_at' => now(), 'created_at' => $before?->created_at ?? now()],
        );
        $after = (array) DB::table('national_id_area_eligibilities')
            ->where('national_id_prefix_3', $prefix)
            ->first();
        $this->audit->record($request, $this->admin($request), 'upsert_national_id_range', 'national_id_area_eligibilities', $prefix, $before === null ? null : (array) $before, $after);

        return response()->json(['data' => $after], $before === null ? 201 : 200);
    }

    private function geoList(Request $request, string $modelClass, array $columns): JsonResponse
    {
        /** @var Model $model */
        $model = new $modelClass();
        $query = $modelClass::query()->select($columns)->orderBy('name_fa');

        return response()->json($query->paginate(50));
    }

    private function storeGeo(Request $request, string $modelClass, array $data, string $table): JsonResponse
    {
        $model = DB::transaction(function () use ($request, $modelClass, $data, $table): Model {
            $model = $modelClass::create($data);
            $this->audit->record($request, $this->admin($request), "create_{$table}", $table, $model->getKey(), null, $model->toArray());

            return $model;
        });

        return response()->json(['data' => $model], 201);
    }

    private function updateGeo(Request $request, string $modelClass, int $id, array $rules, string $table): JsonResponse
    {
        $model = $modelClass::query()->findOrFail($id);
        $data = $request->validate($rules);
        $before = $model->toArray();
        DB::transaction(function () use ($request, $model, $data, $table, $before): void {
            $model->update($data);
            $this->audit->record($request, $this->admin($request), "update_{$table}", $table, $model->getKey(), $before, $model->fresh()->toArray());
        });

        return response()->json(['data' => $model->fresh()]);
    }

    private function publishContent(Request $request, string $modelClass, int $id, string $table, string $action): Model
    {
        return DB::transaction(function () use ($request, $modelClass, $id, $table, $action): Model {
            $content = $modelClass::query()->findOrFail($id);
            $before = $content->toArray();
            $modelClass::query()->whereKeyNot($content->getKey())->update(['is_active' => false]);
            $content->update(['is_active' => true, 'published_at' => now()]);
            $this->audit->record($request, $this->admin($request), $action, $table, $content->getKey(), $before, $content->fresh()->toArray());

            return $content->fresh();
        });
    }

    private function deactivateOtherContent(string $modelClass, int|string $exceptId): void
    {
        $modelClass::query()->whereKeyNot($exceptId)->where('is_active', true)->update(['is_active' => false]);
    }

    private function admin(Request $request): \App\Models\SystemAdmin
    {
        return $request->attributes->get('system_admin');
    }
}
