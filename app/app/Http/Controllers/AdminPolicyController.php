<?php

namespace App\Http\Controllers;

use App\Models\AccountClosurePenaltyPolicy;
use App\Models\GeoCooldownPolicy;
use App\Models\ProcessLifecyclePolicyVersion;
use App\Services\AdminAuditService;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

class AdminPolicyController extends Controller
{
    public function __construct(private readonly AdminAuditService $audit)
    {
    }

    public function processLifecyclePolicies(): JsonResponse
    {
        return response()->json([
            'data' => ProcessLifecyclePolicyVersion::query()
                ->orderByDesc('version_number')->limit(50)->get(),
        ]);
    }

    /**
     * Lifecycle policies are immutable versions. Saving settings creates and activates
     * a new version, so processes already bound to an earlier version keep their rules.
     */
    public function createProcessLifecyclePolicy(Request $request): JsonResponse
    {
        $data = $request->validate([
            'threshold_rate_ppm' => ['required', 'integer', 'min:1', 'max:1000000'],
            'min_support_count' => ['required', 'integer', 'min:0', 'max:9223372036854775807'],
            'support_period_days' => ['required', 'integer', 'min:1', 'max:3650'],
            'waiting_period_days' => ['required', 'integer', 'min:1', 'max:3650'],
            'voting_period_days' => ['required', 'integer', 'min:1', 'max:3650'],
            'publication_delay_hours' => ['required', 'integer', 'min:1', 'max:87600'],
        ]);

        $policy = DB::transaction(function () use ($request, $data): ProcessLifecyclePolicyVersion {
            $now = now();
            $version = ((int) ProcessLifecyclePolicyVersion::query()->lockForUpdate()->max('version_number')) + 1;
            $activePolicy = ProcessLifecyclePolicyVersion::query()
                ->where('is_active', true)
                ->lockForUpdate()
                ->first();
            if ($activePolicy !== null && $activePolicy->effective_from->greaterThanOrEqualTo($now)) {
                $now = $activePolicy->effective_from->copy()->addSecond();
            }
            $code = 'PROCESS_LIFECYCLE_V'.$version;
            $ratePpm = (int) $data['threshold_rate_ppm'];

            DB::table('support_threshold_policy_lookups')->insert([
                'support_threshold_policy_code' => $code,
                'policy_name' => 'سیاست چرخه فرایند نسخه '.$version,
                'threshold_rate_ppm' => $ratePpm,
                'rounding_mode_code' => 'CEIL',
                'min_support_count' => $data['min_support_count'],
                'is_active' => true,
                'created_at' => $now,
                'updated_at' => $now,
            ]);

            $activePolicy?->update([
                'is_active' => false,
                'effective_to' => $now,
            ]);

            $policy = ProcessLifecyclePolicyVersion::query()->create([
                'version_number' => $version,
                'support_threshold_policy_code' => $code,
                'threshold_rate_ppm' => $ratePpm,
                'rounding_mode_code' => 'CEIL',
                'min_support_count' => $data['min_support_count'],
                'support_period_seconds' => (int) $data['support_period_days'] * 86400,
                'waiting_period_seconds' => (int) $data['waiting_period_days'] * 86400,
                'voting_period_seconds' => (int) $data['voting_period_days'] * 86400,
                'publication_delay_seconds' => (int) $data['publication_delay_hours'] * 3600,
                'is_active' => true,
                'effective_from' => $now,
                'effective_to' => null,
                'created_by_admin_id' => $this->admin($request)->admin_id,
                'created_at' => $now,
            ]);

            $this->audit->record(
                $request,
                $this->admin($request),
                'create_process_lifecycle_policy_version',
                'process_lifecycle_policy_versions',
                $policy->getKey(),
                null,
                $policy->toArray(),
            );

            return $policy;
        });

        return response()->json(['data' => $policy], 201);
    }

    public function geoCooldownPolicies(): JsonResponse
    {
        return response()->json([
            'data' => GeoCooldownPolicy::query()
                ->orderBy('policy_code')
                ->orderBy('policy_stage')
                ->paginate(50),
        ]);
    }

    public function storeGeoCooldownPolicy(Request $request): JsonResponse
    {
        $data = $request->validate($this->geoRules());

        return $this->store($request, GeoCooldownPolicy::class, $data, 'geo_cooldown_policies');
    }

    public function updateGeoCooldownPolicy(Request $request, int $id): JsonResponse
    {
        return $this->update(
            $request,
            GeoCooldownPolicy::class,
            $id,
            $this->geoRules($id, true),
            'geo_cooldown_policies',
        );
    }

    public function deleteGeoCooldownPolicy(Request $request, int $id): JsonResponse
    {
        return $this->delete($request, GeoCooldownPolicy::class, $id, 'geo_cooldown_policies');
    }

    public function accountClosurePenaltyPolicies(): JsonResponse
    {
        return response()->json([
            'data' => AccountClosurePenaltyPolicy::query()
                ->orderBy('policy_family_code')
                ->orderBy('policy_code')
                ->orderBy('penalty_stage')
                ->paginate(50),
        ]);
    }

    public function storeAccountClosurePenaltyPolicy(Request $request): JsonResponse
    {
        $data = $request->validate($this->closureRules());

        return $this->store($request, AccountClosurePenaltyPolicy::class, $data, 'account_closure_penalty_policies');
    }

    public function updateAccountClosurePenaltyPolicy(Request $request, int $id): JsonResponse
    {
        return $this->update(
            $request,
            AccountClosurePenaltyPolicy::class,
            $id,
            $this->closureRules($id, true),
            'account_closure_penalty_policies',
        );
    }

    public function deleteAccountClosurePenaltyPolicy(Request $request, int $id): JsonResponse
    {
        return $this->delete($request, AccountClosurePenaltyPolicy::class, $id, 'account_closure_penalty_policies');
    }

    private function geoRules(?int $id = null, bool $partial = false): array
    {
        $unique = Rule::unique('geo_cooldown_policies', 'policy_code')
            ->where(fn ($query) => $query->where('policy_stage', request()->input('policy_stage')));
        if ($id !== null) {
            $unique->ignore($id, 'policy_id');
        }

        return [
            'policy_code' => [$partial ? 'sometimes' : 'required', 'string', 'max:50', $unique],
            'policy_name' => [$partial ? 'sometimes' : 'required', 'string', 'max:150'],
            'description' => ['nullable', 'string', 'max:500'],
            'policy_stage' => [$partial ? 'sometimes' : 'required', 'integer', 'between:1,255'],
            'max_changes_allowed' => ['nullable', 'integer', 'between:0,255'],
            'window_days' => ['nullable', 'integer', 'between:0,65535'],
            'cooldown_days' => [$partial ? 'sometimes' : 'required', 'integer', 'min:0', 'max:65535'],
            'is_active' => ['sometimes', 'boolean'],
            'effective_from' => [$partial ? 'sometimes' : 'required', 'date'],
            'effective_to' => ['nullable', 'date', 'after_or_equal:effective_from'],
        ];
    }

    private function closureRules(?int $id = null, bool $partial = false): array
    {
        $unique = Rule::unique('account_closure_penalty_policies', 'policy_family_code')
            ->where(fn ($query) => $query
                ->where('policy_code', request()->input('policy_code'))
                ->where('penalty_stage', request()->input('penalty_stage')));
        if ($id !== null) {
            $unique->ignore($id, 'policy_id');
        }

        return [
            'policy_family_code' => [$partial ? 'sometimes' : 'required', 'string', 'max:50', $unique],
            'policy_code' => [$partial ? 'sometimes' : 'required', 'string', 'max:50'],
            'policy_name' => [$partial ? 'sometimes' : 'required', 'string', 'max:150'],
            'description' => ['nullable', 'string', 'max:500'],
            'penalty_stage' => [$partial ? 'sometimes' : 'required', 'integer', 'between:1,255'],
            'penalty_hours' => [$partial ? 'sometimes' : 'required', 'integer', 'min:0', 'max:4294967295'],
            'trigger_scope' => [$partial ? 'sometimes' : 'required', 'string', 'max:50'],
            'is_active' => ['sometimes', 'boolean'],
            'effective_from' => [$partial ? 'sometimes' : 'required', 'date'],
            'effective_to' => ['nullable', 'date', 'after_or_equal:effective_from'],
        ];
    }

    private function store(Request $request, string $modelClass, array $data, string $table): JsonResponse
    {
        $model = DB::transaction(function () use ($request, $modelClass, $data, $table): Model {
            $model = $modelClass::create($data);
            $this->audit->record($request, $this->admin($request), "create_{$table}", $table, $model->getKey(), null, $model->toArray());

            return $model;
        });

        return response()->json(['data' => $model], 201);
    }

    private function update(Request $request, string $modelClass, int $id, array $rules, string $table): JsonResponse
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

    private function delete(Request $request, string $modelClass, int $id, string $table): JsonResponse
    {
        DB::transaction(function () use ($request, $modelClass, $id, $table): void {
            $model = $modelClass::query()->findOrFail($id);
            $before = $model->toArray();
            $model->delete();
            $this->audit->record($request, $this->admin($request), "delete_{$table}", $table, $id, $before, null);
        });

        return response()->json(['message' => 'Policy حذف شد.']);
    }

    private function admin(Request $request): \App\Models\SystemAdmin
    {
        return $request->attributes->get('system_admin');
    }
}
