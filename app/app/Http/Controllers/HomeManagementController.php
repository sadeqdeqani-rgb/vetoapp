<?php

namespace App\Http\Controllers;

use App\Services\AdminAuditService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class HomeManagementController extends Controller
{
    public const SECTIONS = ['goals', 'identity', 'activation', 'validation', 'technical', 'creators', 'gateway_intro'];

    public function __construct(private readonly AdminAuditService $audit) {}

    public function publicSections(): JsonResponse
    {
        return response()->json(['data' => DB::table('home_introduction_sections')
            ->where('is_published', true)->where('section_key', '<>', 'gateway_intro')
            ->orderByRaw("FIELD(section_key, 'goals', 'identity', 'activation', 'validation', 'technical', 'creators')")
            ->get(['section_key', 'title', 'body_text'])]);
    }

    public function publicGatewayIntroduction(): JsonResponse
    {
        $content = DB::table('home_introduction_sections')
            ->where('section_key', 'gateway_intro')
            ->first(['section_key', 'title', 'body_text']);

        return response()->json(['data' => $content ?? [
            'section_key' => 'gateway_intro',
            'title' => 'آشنایی با وتواپ',
            'body_text' => 'وتواپ بستری برای پیشنهاد و حمایت از موضوعات همه‌پرسی، مشارکت در انتخابات و درخواست استیضاح است. در نسخهٔ تعاملی می‌توانید با شیوهٔ کار بخش‌های مختلف آشنا شوید و درخواست فعال‌سازی سامانه را ثبت کنید.',
        ]])->header('Cache-Control', 'public, max-age=60');
    }

    public function sections(): JsonResponse
    {
        return response()->json(['data' => DB::table('home_introduction_sections')->orderBy('id')->get()]);
    }

    public function saveSection(Request $request, string $key): JsonResponse
    {
        abort_unless(in_array($key, self::SECTIONS, true), 404);
        $data = $request->validate([
            'title' => ['required', 'string', 'max:160'],
            'body_text' => ['required', 'string'],
            'is_published' => ['required', 'boolean'],
        ]);
        $before = DB::table('home_introduction_sections')->where('section_key', $key)->first();
        DB::transaction(function () use ($request, $key, $data, $before): void {
            DB::table('home_introduction_sections')->updateOrInsert(
                ['section_key' => $key], $data + ['created_at' => now(), 'updated_at' => now()]
            );
            $after = DB::table('home_introduction_sections')->where('section_key', $key)->first();
            $this->audit->record($request, $request->attributes->get('system_admin'), 'update_home_section', 'home_introduction_sections', $after->id, (array) $before, (array) $after);
        });
        return response()->json(['data' => DB::table('home_introduction_sections')->where('section_key', $key)->first()]);
    }

    public function state(): JsonResponse
    {
        return response()->json(['data' => DB::table('system_states')->where('system_state_id', 1)->first()]);
    }

    public function changeState(Request $request): JsonResponse
    {
        $data = $request->validate(['state_value' => ['required', 'integer', 'between:3,4']]);
        DB::transaction(function () use ($request, $data): void {
            $state = DB::table('system_states')->where('system_state_id', 1)->lockForUpdate()->first();
            if ($state === null) throw ValidationException::withMessages(['state_value' => 'ابتدا وضعیت اولیهٔ سامانه را ایجاد کنید.']);
            $next = (int) $data['state_value'];
            if ($next !== (int) $state->state_value + 1) throw ValidationException::withMessages(['state_value' => 'انتقال فقط به وضعیت بعدی مجاز است.']);
            DB::table('system_states')->where('system_state_id', 1)->update([
                'state_value' => $next, 'state_changed_at' => now(),
                'threshold_reached_at' => $state->threshold_reached_at,
                'changed_by_admin_id' => $request->attributes->get('system_admin')->getKey(),
            ]);
            $this->audit->record($request, $request->attributes->get('system_admin'), 'change_system_state', 'system_states', 1, (array) $state, (array) DB::table('system_states')->where('system_state_id', 1)->first());
        });
        return $this->state();
    }

    public function events(): JsonResponse
    {
        return response()->json(['data' => DB::table('home_active_events')
            ->where('is_active', true)
            ->orderByDesc('created_at')
            ->limit(30)
            ->get(['id', 'kind', 'title', 'created_at'])]);
    }
}
