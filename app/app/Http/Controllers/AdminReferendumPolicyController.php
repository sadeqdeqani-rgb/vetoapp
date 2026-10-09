<?php

namespace App\Http\Controllers;

use App\Services\AdminAuditService;
use App\Services\ReferendumSubjectNormalizer;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class AdminReferendumPolicyController extends Controller
{
    public function __construct(
        private readonly AdminAuditService $audit,
        private readonly ReferendumSubjectNormalizer $normalizer,
    ) {}

    public function directionalTerms(): JsonResponse
    {
        return response()->json(['data' => DB::table('referendum_directional_terms')
            ->orderBy('term')->get(['directional_term_id', 'term', 'is_active', 'created_at', 'updated_at'])]);
    }

    public function storeDirectionalTerm(Request $request): JsonResponse
    {
        $data = $request->validate(['term' => ['required', 'string', 'min:2', 'max:120']]);
        $term = $this->normalizer->normalize($data['term']);
        if ($this->characterLength($term) < 2) throw ValidationException::withMessages(['term' => ['عبارت معتبر نیست.']]);
        $hash = $this->normalizer->hash($term);
        $admin = $request->attributes->get('system_admin');

        $record = DB::transaction(function () use ($request, $admin, $term, $hash) {
            $existing = DB::table('referendum_directional_terms')->where('normalized_term_hash', $hash)->lockForUpdate()->first();
            if ($existing !== null) {
                $before = (array) $existing;
                DB::table('referendum_directional_terms')->where('directional_term_id', $existing->directional_term_id)
                    ->update(['term' => $term, 'normalized_term' => $term, 'is_active' => true, 'updated_at' => now()]);
                $after = (array) DB::table('referendum_directional_terms')->where('directional_term_id', $existing->directional_term_id)->first();
                $id = (int) $existing->directional_term_id;
            } else {
                $id = DB::table('referendum_directional_terms')->insertGetId([
                    'term' => $term,
                    'normalized_term' => $term,
                    'normalized_term_hash' => $hash,
                    'is_active' => true,
                    'created_by_admin_id' => $admin->admin_id,
                    'created_at' => now(),
                    'updated_at' => now(),
                ]);
                $before = null;
                $after = (array) DB::table('referendum_directional_terms')->where('directional_term_id', $id)->first();
            }
            $this->audit->record($request, $admin, 'save_referendum_directional_term', 'referendum_directional_terms', $id, $before, $after);
            return DB::table('referendum_directional_terms')->where('directional_term_id', $id)->first();
        });

        return response()->json(['data' => $record], 201);
    }

    public function updateDirectionalTerm(Request $request, int $id): JsonResponse
    {
        $data = $request->validate([
            'term' => ['sometimes', 'required', 'string', 'min:2', 'max:120'],
            'is_active' => ['sometimes', 'required', 'boolean'],
        ]);
        $record = DB::table('referendum_directional_terms')->where('directional_term_id', $id)->first();
        abort_if($record === null, 404);
        $before = (array) $record;
        $update = ['updated_at' => now()];
        if (array_key_exists('is_active', $data)) $update['is_active'] = $data['is_active'];
        if (array_key_exists('term', $data)) {
            $normalized = $this->normalizer->normalize($data['term']);
            if ($this->characterLength($normalized) < 2) {
                throw ValidationException::withMessages(['term' => ['عبارت معتبر نیست.']]);
            }
            $hash = $this->normalizer->hash($normalized);
            $duplicate = DB::table('referendum_directional_terms')->where('normalized_term_hash', $hash)
                ->where('directional_term_id', '!=', $id)->exists();
            if ($duplicate) throw ValidationException::withMessages(['term' => ['این عبارت از قبل ثبت شده است.']]);
            $update['term'] = $normalized;
            $update['normalized_term'] = $normalized;
            $update['normalized_term_hash'] = $hash;
        }

        DB::transaction(function () use ($request, $id, $update, $before): void {
            DB::table('referendum_directional_terms')->where('directional_term_id', $id)->update($update);
            $after = (array) DB::table('referendum_directional_terms')->where('directional_term_id', $id)->first();
            $this->audit->record($request, $request->attributes->get('system_admin'), 'update_referendum_directional_term', 'referendum_directional_terms', $id, $before, $after);
        });

        return response()->json(['data' => DB::table('referendum_directional_terms')->where('directional_term_id', $id)->first()]);
    }

    private function characterLength(string $value): int
    {
        return function_exists('mb_strlen') ? mb_strlen($value, 'UTF-8') : strlen($value);
    }
}
