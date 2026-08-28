<?php

namespace App\Http\Controllers;

use App\Models\AccountClosurePenaltyPolicy;
use App\Models\GeoCooldownPolicy;
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
            'cooldown_days' => [$partial ? 'sometimes' : 'required', 'integer', 'min:1', 'max:65535'],
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
            'penalty_hours' => [$partial ? 'sometimes' : 'required', 'integer', 'min:1', 'max:4294967295'],
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
