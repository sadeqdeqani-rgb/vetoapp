<?php

namespace App\Http\Controllers;

use App\Models\UserProfile;
use App\Services\SystemStateService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class DashboardController extends Controller
{
    public function __construct(private readonly SystemStateService $systemState)
    {
    }

    public function publicActiveUsers(): JsonResponse
    {
        $this->systemState->activateReferendumAtThreshold();

        return response()->json([
            'data' => [
                'active_user_count' => UserProfile::query()->where('is_active', true)->count(),
            ],
        ])->header('Cache-Control', 'public, max-age=15');
    }

    public function publicGeographyUserCounts(Request $request): JsonResponse
    {
        $data = $request->validate([
            'level' => ['required', 'in:province,county,settlement'],
            'parent_id' => ['nullable', 'integer', 'min:1'],
        ]);

        $level = $data['level'];
        $parentId = isset($data['parent_id']) ? (int) $data['parent_id'] : null;
        $iranId = DB::table('countries')->where('country_code', 364)->value('country_id');

        if ($level === 'province') {
            $rows = DB::table('provinces as p')
                ->leftJoin('user_profiles as u', function ($join): void {
                    $join->on('u.province_id', '=', 'p.province_id')->where('u.is_active', true);
                })
                ->where('p.is_active', true)
                ->where('p.country_id', $iranId)
                ->groupBy('p.province_id', 'p.name_fa')
                ->orderBy('p.name_fa')
                ->get(['p.province_id as id', 'p.country_id as parent_id', 'p.name_fa as name', DB::raw('COUNT(u.user_id) as active_user_count')]);
        } elseif ($level === 'county') {
            abort_if($parentId === null, 422, 'استان انتخاب‌شده معتبر نیست.');
            $rows = DB::table('counties as c')
                ->join('provinces as p', 'p.province_id', '=', 'c.province_id')
                ->leftJoin('user_profiles as u', function ($join): void {
                    $join->on('u.county_id', '=', 'c.county_id')->where('u.is_active', true);
                })
                ->where('c.is_active', true)
                ->where('p.is_active', true)
                ->where('p.country_id', $iranId)
                ->where('c.province_id', $parentId)
                ->groupBy('c.county_id', 'c.province_id', 'c.name_fa')
                ->orderBy('c.name_fa')
                ->get(['c.county_id as id', 'c.province_id as parent_id', 'c.name_fa as name', DB::raw('COUNT(u.user_id) as active_user_count')]);
        } else {
            abort_if($parentId === null, 422, 'شهرستان انتخاب‌شده معتبر نیست.');
            $rows = DB::table('settlements as s')
                ->join('counties as c', 'c.county_id', '=', 's.county_id')
                ->join('provinces as p', 'p.province_id', '=', 'c.province_id')
                ->leftJoin('user_profiles as u', function ($join): void {
                    $join->on('u.settlement_id', '=', 's.settlement_id')->where('u.is_active', true);
                })
                ->where('s.is_active', true)
                ->where('c.is_active', true)
                ->where('p.is_active', true)
                ->where('p.country_id', $iranId)
                ->where('s.county_id', $parentId)
                ->groupBy('s.settlement_id', 's.county_id', 's.name_fa')
                ->orderBy('s.name_fa')
                ->get(['s.settlement_id as id', 's.county_id as parent_id', 's.name_fa as name', DB::raw('COUNT(u.user_id) as active_user_count')]);
        }

        return response()->json(['data' => $rows])->header('Cache-Control', 'public, max-age=15');
    }

    public function summary(): JsonResponse
    {
        $this->systemState->activateReferendumAtThreshold();

        $active = UserProfile::query()->where('is_active', true)->count();
        $state = DB::table('system_states')->where('system_state_id', 1)->first();
        $stateCode = (int) ($state?->state_value ?? 1);
        $sections = DB::table('home_introduction_sections')->where('is_published', true)
            ->orderByRaw("FIELD(section_key, 'goals', 'identity', 'activation', 'validation', 'technical', 'creators')")
            ->get(['section_key', 'title', 'body_text']);
        $iranId = DB::table('countries')->where('country_code', 364)->value('country_id');
        $provinces = DB::table('provinces as p')->leftJoin('user_profiles as u', function ($join) {
            $join->on('u.province_id', '=', 'p.province_id')->where('u.is_active', true);
        })->where('p.is_active', true)->where('p.country_id', $iranId)->groupBy('p.province_id', 'p.name_fa')
            ->orderBy('p.name_fa')->get(['p.province_id as id', 'p.name_fa as name', DB::raw('COUNT(u.user_id) as active_user_count')]);
        $counties = DB::table('counties as c')->leftJoin('user_profiles as u', function ($join) {
            $join->on('u.county_id', '=', 'c.county_id')->where('u.is_active', true);
        })->where('c.is_active', true)->groupBy('c.county_id', 'c.province_id', 'c.name_fa')->orderBy('c.name_fa')
            ->get(['c.county_id as id', 'c.province_id as parent_id', 'c.name_fa as name', DB::raw('COUNT(u.user_id) as active_user_count')]);
        $settlements = DB::table('settlements as s')->leftJoin('user_profiles as u', function ($join) {
            $join->on('u.settlement_id', '=', 's.settlement_id')->where('u.is_active', true);
        })->where('s.is_active', true)->groupBy('s.settlement_id', 's.county_id', 's.name_fa')->orderBy('s.name_fa')
            ->get(['s.settlement_id as id', 's.county_id as parent_id', 's.name_fa as name', DB::raw('COUNT(u.user_id) as active_user_count')]);
        $events = $stateCode < 2 ? [] : DB::table('home_active_events')->where('is_active', true)
            ->whereIn('kind', $stateCode === 2 ? ['referendum'] : ($stateCode === 3 ? ['referendum', 'election'] : ['referendum', 'election', 'impeachment']))
            ->orderByDesc('created_at')->limit(30)->get(['id', 'kind', 'title', 'created_at']);
        return response()->json([
            'data' => [
                'active_user_count' => $active,
                'introduction_sections' => $sections,
                'geography' => ['provinces' => $provinces, 'counties' => $counties, 'settlements' => $settlements],
                'system_state' => ['code' => $stateCode,
                    'title' => DB::table('system_state_lookups')->where('state_code', $stateCode)->value('state_name'),
                    'remaining_users' => $stateCode === 1 ? max(0, (int) ($state?->activation_user_threshold ?? 44000000) - $active) : null],
                'active_events' => $events,
            ],
        ]);
    }
}
