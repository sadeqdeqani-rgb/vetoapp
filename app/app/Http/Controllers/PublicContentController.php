<?php

namespace App\Http\Controllers;

use App\Models\SystemIntroductionContent;
use App\Models\SystemIntroductionVideo;
use App\Models\SystemTermsContent;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Http\JsonResponse;

class PublicContentController extends Controller
{
    public function introduction(): JsonResponse
    {
        return $this->contentResponse(
            SystemIntroductionContent::query()
                ->published()
                ->orderByDesc('version_number')
                ->firstOrFail(),
        );
    }

    public function terms(): JsonResponse
    {
        return $this->contentResponse(
            SystemTermsContent::query()
                ->published()
                ->orderByDesc('version_number')
                ->firstOrFail(),
        );
    }

    public function introductionVideo(): JsonResponse
    {
        return $this->contentResponse(
            SystemIntroductionVideo::query()
                ->published()
                ->orderByDesc('version_number')
                ->firstOrFail(),
        );
    }

    private function contentResponse(Model $content): JsonResponse
    {
        return response()->json(['data' => $content]);
    }
}
