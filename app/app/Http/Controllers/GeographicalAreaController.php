<?php

namespace App\Http\Controllers;

use App\Models\Country;
use App\Models\County;
use App\Models\Province;
use App\Models\Settlement;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class GeographicalAreaController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $parentId = $request->integer('parent_id');
        $childType = $request->string('child_type')->toString();

        if ($parentId === 0) {
            $parentId = null;
        }

        if ($parentId === null || $childType === 'country') {
            $items = Country::query()->active()->orderBy('name_fa')->get()
                ->map(fn (Country $row) => $this->row($row, 'country', 'country_id', null));
        } elseif ($childType === 'county') {
            $province = Province::query()->active()->whereKey($parentId)->firstOrFail();
            $items = County::query()
                ->active()
                ->where('province_id', $province->province_id)
                ->whereHas('province.country', fn (Builder $q) => $q->where('is_active', true))
                ->orderBy('name_fa')->get()
                ->map(fn (County $row) => $this->row($row, 'county', 'county_id', $row->province_id));
        } elseif ($childType === 'locality') {
            $county = County::query()->active()->whereKey($parentId)->firstOrFail();
            $items = Settlement::query()
                ->active()
                ->where('county_id', $county->county_id)
                ->whereHas('county.province.country', function (Builder $q): void {
                    $q->where('is_active', true);
                })
                ->orderBy('name_fa')->get()
                ->map(fn (Settlement $row) => $this->row($row, 'locality', 'settlement_id', $row->county_id));
        } elseif ($childType === 'province') {
            $items = Province::query()
                ->active()
                ->where('country_id', $parentId)
                ->whereHas('country', fn (Builder $q) => $q->where('is_active', true))
                ->orderBy('name_fa')->get()
                ->map(fn (Province $row) => $this->row($row, 'province', 'province_id', $row->country_id));
        } else {
            return response()->json(['message' => 'نوع حوزه جغرافیایی معتبر نیست.'], 422);
        }

        return response()->json(['data' => $items->values()]);
    }

    private function row(object $model, string $type, string $idColumn, ?int $parentId): array
    {
        return [
            'id' => (int) $model->{$idColumn},
            'parent_id' => $parentId,
            'name' => $model->name_fa,
            'type' => $type,
        ];
    }
}
