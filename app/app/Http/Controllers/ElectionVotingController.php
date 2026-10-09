<?php

namespace App\Http\Controllers;

use App\Services\ProcessReceiptSigner;
use App\Services\ElectionCandidateNormalizer;
use Illuminate\Database\Query\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpKernel\Exception\ConflictHttpException;
use Symfony\Component\HttpKernel\Exception\UnprocessableEntityHttpException;

class ElectionVotingController extends Controller
{
    public function __construct(private readonly ProcessReceiptSigner $receipts, private readonly ElectionCandidateNormalizer $candidates) {}

    public function index(Request $request, string $electionType, string $kind): JsonResponse
    {
        abort_unless(in_array($kind, ['scheduled', 'eligible', 'live', 'finalized'], true), 404);
        $scopeLevel = $this->scopeLevel($electionType);
        $data = $request->validate([
            'search' => ['nullable', 'string', 'max:100'],
            'geographic_level_code' => ['nullable', 'integer', 'between:1,4'],
            'geographic_id' => ['nullable', 'integer', 'min:1'],
            'page' => ['nullable', 'integer', 'min:1'],
            'per_page' => ['nullable', 'integer', 'between:1,50'],
        ]);
        if (isset($data['geographic_level_code']) !== isset($data['geographic_id'])) {
            throw ValidationException::withMessages(['geographic_id' => ['سطح و شناسهٔ حوزه باید با هم ارسال شوند.']]);
        }
        $query = $this->processQuery($kind, $scopeLevel);
        if (($data['search'] ?? '') !== '') $query->where('p.title', 'like', '%'.$data['search'].'%');
        if (isset($data['geographic_level_code'])) $this->filterWithinGeography($query, (int) $data['geographic_level_code'], (int) $data['geographic_id']);
        if ($kind === 'eligible') $this->filterEligible($query, $request->attributes->get('user_profile'));
        $page = (int) ($data['page'] ?? 1);
        $perPage = (int) ($data['per_page'] ?? 30);
        $total = (clone $query)->count('p.process_id');
        $rows = $query->orderBy($kind === 'scheduled' ? 'p.voting_opens_at' : 'ps.current_state_started_at')
            ->offset(($page - 1) * $perPage)->limit($perPage)->get();

        return response()->json(['data' => [
            'items' => $rows->map(fn (object $row): array => $this->summary($row, $kind))->all(),
            'pagination' => ['page' => $page, 'per_page' => $perPage, 'total' => $total],
        ]]);
    }

    public function show(Request $request, string $electionType, int $processId): JsonResponse
    {
        $scopeLevel = $this->scopeLevel($electionType);
        $row = $this->processQuery('any', $scopeLevel)->where('p.process_id', $processId)->first();
        abort_if($row === null, 404);
        $profile = $request->attributes->get('user_profile');
        $identity = $this->voterIdentityKey((string) $profile->national_id_hash);
        $alreadyVoted = DB::table('voter_participations')->where('process_id', $processId)
            ->where('participant_identity_key', $identity)->exists();
        $canVote = $row->current_state_code === 'VoteCasting'
            && Carbon::parse($row->voting_closes_at)->isFuture()
            && $this->profileMatchesTarget($row, $profile)
            && ! $alreadyVoted;
        $data = $this->summary($row, 'any');
        $data['can_vote'] = $canVote;
        $data['already_voted'] = $alreadyVoted;
        $data['eligible_geography_matches'] = $this->profileMatchesTarget($row, $profile);
        return response()->json(['data' => $data]);
    }

    public function results(Request $request, string $electionType, int $processId): JsonResponse
    {
        $scopeLevel = $this->scopeLevel($electionType);
        $data = $request->validate([
            'geographic_level_code' => ['nullable', 'integer', 'between:1,4'],
            'geographic_id' => ['nullable', 'integer', 'min:1'],
        ]);
        if (isset($data['geographic_level_code']) !== isset($data['geographic_id'])) {
            throw ValidationException::withMessages(['geographic_id' => ['سطح و شناسهٔ حوزه باید با هم ارسال شوند.']]);
        }
        $process = $this->processQuery('any', $scopeLevel)->where('p.process_id', $processId)->first();
        abort_if($process === null, 404);
        $selectedLevel = (int) ($data['geographic_level_code'] ?? $process->target_geographic_level_code);
        $selectedId = (int) ($data['geographic_id'] ?? $process->target_geographic_id);
        $this->assertGeographyWithinProcess($process, $selectedLevel, $selectedId);
        $level = max($selectedLevel, (int) $process->target_geographic_level_code);
        $geoId = $selectedLevel < (int) $process->target_geographic_level_code
            ? (int) $process->target_geographic_id
            : $selectedId;

        $totals = DB::table('process_geographic_counters as c')
            ->join('process_ballot_options as o', function ($join): void { $join->on('o.process_id', '=', 'c.process_id')->on('o.option_key', '=', 'c.ballot_choice_key'); })
            ->where('c.process_id', $processId)->where('c.counter_type', 'VOTE')
            ->where('c.geographic_level_code', $level)->where('c.geographic_id', $geoId)
            ->whereNotNull('o.election_candidate_id')->orderByDesc('c.counter_value')
            ->get(['o.election_candidate_id', 'o.option_key', 'o.display_label', 'c.counter_value']);
        $candidateTotals = $totals->map(fn ($row): array => [
            'candidate_id' => (int) $row->election_candidate_id, 'choice_key' => $row->option_key,
            'candidate' => $row->display_label, 'votes' => (int) $row->counter_value,
        ])->all();
        $childLevel = $level + 1;
        $items = $childLevel <= 4 ? $this->electionResultChildren($processId, $level, $geoId, $childLevel) : [];
        $checkpoint = DB::table('process_merkle_trees')->where('process_id', $processId)
            ->where('checkpoint_kind', 'FINAL')->whereNotNull('published_at')->orderByDesc('checkpoint_no')->first();
        $treeHead = null;
        if ($checkpoint !== null) {
            $finalHead = DB::table('process_chain_heads')->where('process_id', $processId)->first();
            $lastChainHash = (string) ($finalHead?->last_hash ?? str_repeat("\0", 32));
            $treeHead = [
                'domain' => 'vetoapp-signed-tree-head-v1',
                'process_id' => (string) $processId,
                'checkpoint_no' => (int) $checkpoint->checkpoint_no,
                'checkpoint_kind' => $checkpoint->checkpoint_kind,
                'root_hash' => $this->base64Url((string) $checkpoint->root_hash),
                'tree_version' => $checkpoint->tree_version,
                'chain_hash_version' => $finalHead?->hash_version,
                'canonical_encoding_version' => (int) $checkpoint->canonical_encoding_version,
                'leaf_count' => (int) $checkpoint->leaf_count,
                'last_sequence_no' => (int) $checkpoint->last_sequence_no,
                'last_chain_hash' => $this->base64Url($lastChainHash),
                'source_outbox_watermark' => (int) $checkpoint->source_outbox_watermark,
                'generated_at' => Carbon::parse($checkpoint->generated_at, 'UTC')->format('Y-m-d\\TH:i:s.u\\Z'),
                'signing_key_id' => $checkpoint->signing_key_id,
                'previous_checkpoint_id' => $checkpoint->previous_checkpoint_id === null ? null : (int) $checkpoint->previous_checkpoint_id,
            ];
        }

        return response()->json(['data' => [
            'process_id' => $processId,
            'geographic_level_code' => $level,
            'geographic_id' => $geoId,
            'totals' => ['candidates' => $candidateTotals, 'votes' => array_sum(array_column($candidateTotals, 'votes'))],
            'items' => $items,
            'checkpoint' => $checkpoint === null ? null : [
                'checkpoint_no' => (int) $checkpoint->checkpoint_no,
                'root_hash' => $this->base64Url((string) $checkpoint->root_hash),
                'tree_version' => $checkpoint->tree_version,
                'chain_hash_version' => $treeHead['chain_hash_version'],
                'canonical_encoding_version' => (int) $checkpoint->canonical_encoding_version,
                'leaf_count' => (int) $checkpoint->leaf_count,
                'last_sequence_no' => (int) $checkpoint->last_sequence_no,
                'source_outbox_watermark' => (int) $checkpoint->source_outbox_watermark,
                'last_chain_hash' => $treeHead['last_chain_hash'],
                'checkpoint_kind' => $checkpoint->checkpoint_kind,
                'generated_at' => $treeHead['generated_at'],
                'previous_checkpoint_id' => $treeHead['previous_checkpoint_id'],
                'signed_tree_head' => $treeHead,
                'signed_payload' => $this->canonical($treeHead),
                'signature' => $this->base64Url((string) $checkpoint->signature_value),
                'key_id' => $checkpoint->signing_key_id,
                'signature_algorithm' => 'Ed25519',
                'published_at' => $checkpoint->published_at,
            ],
        ]]);
    }

    public function candidatePreview(Request $request, string $electionType, int $processId): JsonResponse
    {
        $scopeLevel = $this->scopeLevel($electionType);
        $data = $request->validate([
            'given_name' => ['required', 'string', 'min:1', 'max:100'],
            'family_name' => ['required', 'string', 'min:1', 'max:120'],
            'father_name' => ['required', 'string', 'min:1', 'max:100'],
        ]);
        $process = DB::table('processes as p')->join('process_shard_placements as pl', function ($join): void {
            $join->on('pl.process_id', '=', 'p.process_id')->where('pl.placement_state_code', 'ACTIVE');
        })->join('process_states as ps', function ($join): void {
            $join->on('ps.process_id', '=', 'p.process_id')->whereNull('ps.current_state_completed_at');
        })->where('p.process_id', $processId)->where('p.process_type_code', 'Election')
            ->where('p.target_geographic_level_code', $scopeLevel)
            ->where('ps.current_state_code', 'VoteCasting')->where('p.voting_closes_at', '>', now())->first(['p.process_id']);
        abort_if($process === null, 404);

        $normalized = $this->candidates->normalize($data['given_name'], $data['family_name'], $data['father_name']);
        $this->assertCandidateNameComplete($normalized);
        $exactCandidate = DB::table('election_candidates')->where('process_id', $processId)
            ->where('normalized_identity_hash', $normalized['hash'])->first();
        $candidates = DB::table('election_candidates')->where('process_id', $processId)
            ->orderByDesc('election_candidate_id')->limit(500)->get();
        if ($exactCandidate !== null && ! $candidates->contains('election_candidate_id', $exactCandidate->election_candidate_id)) {
            $candidates->prepend($exactCandidate);
        }
        $matches = [];
        foreach ($candidates as $candidate) {
            $candidateName = ['given' => $candidate->normalized_given_name, 'family' => $candidate->normalized_family_name, 'father' => $candidate->normalized_father_name];
            $score = $this->candidates->similarity($normalized, $candidateName);
            if ($score >= 0.62 || hash_equals((string) $candidate->normalized_identity_hash, $normalized['hash'])) {
                $matches[] = [
                    'candidate_id' => (int) $candidate->election_candidate_id,
                    'given_name' => $candidate->display_given_name,
                    'family_name' => $candidate->display_family_name,
                    'father_name' => $candidate->display_father_name,
                    'similarity' => round($score, 4),
                    'exact_normalized_match' => hash_equals((string) $candidate->normalized_identity_hash, $normalized['hash']),
                ];
            }
        }
        usort($matches, fn (array $a, array $b): int => $b['similarity'] <=> $a['similarity']);

        return response()->json(['data' => [
            'normalization_version' => ElectionCandidateNormalizer::VERSION,
            'normalized' => ['given_name' => $normalized['given'], 'family_name' => $normalized['family'], 'father_name' => $normalized['father']],
            'matches' => array_slice($matches, 0, 10),
            'typed' => ['given_name' => $data['given_name'], 'family_name' => $data['family_name'], 'father_name' => $data['father_name']],
        ]]);
    }

    private function electionResultChildren(int $processId, int $parentLevel, int $parentId, int $childLevel): array
    {
        [$table, $idCol] = match ($childLevel) {
            2 => ['provinces', 'province_id'], 3 => ['counties', 'county_id'], 4 => ['settlements', 'settlement_id'], default => ['', ''],
        };
        if ($table === '') return [];
        $geo = DB::table($table.' as g');
        match ([$parentLevel, $childLevel]) {
            [1, 2] => $geo->where('g.country_id', $parentId),
            [2, 3] => $geo->where('g.province_id', $parentId),
            [3, 4] => $geo->where('g.county_id', $parentId),
            default => null,
        };
        $areas = $geo->orderBy('g.name_fa')->limit(300)->get(['g.'.$idCol.' as geographic_id', 'g.name_fa as name']);
        if ($areas->isEmpty()) return [];
        $ids = $areas->pluck('geographic_id')->all();
        $counts = DB::table('process_geographic_counters as c')
            ->join('process_ballot_options as o', function ($join): void { $join->on('o.process_id', '=', 'c.process_id')->on('o.option_key', '=', 'c.ballot_choice_key'); })
            ->where('c.process_id', $processId)->where('c.counter_type', 'VOTE')->where('c.geographic_level_code', $childLevel)
            ->whereIn('c.geographic_id', $ids)->whereNotNull('o.election_candidate_id')
            ->get(['c.geographic_id', 'o.election_candidate_id', 'o.display_label', 'c.counter_value'])
            ->groupBy('geographic_id');
        return $areas->map(fn ($area): array => [
            'geographic_id' => (int) $area->geographic_id, 'name' => $area->name, 'geographic_label' => $this->levelLabel($childLevel),
            'candidates' => ($counts->get($area->geographic_id) ?? collect())->map(fn ($row): array => [
                'candidate_id' => (int) $row->election_candidate_id, 'candidate' => $row->display_label, 'votes' => (int) $row->counter_value,
            ])->values()->all(),
        ])->all();
    }

    public function biometricChallenge(Request $request, string $electionType, int $processId): JsonResponse
    {
        $scopeLevel = $this->scopeLevel($electionType);
        $data = $request->validate([
            'given_name' => ['required', 'string', 'min:1', 'max:100'],
            'family_name' => ['required', 'string', 'min:1', 'max:120'],
            'father_name' => ['required', 'string', 'min:1', 'max:100'],
        ]);
        $candidate = $this->candidates->normalize($data['given_name'], $data['family_name'], $data['father_name']);
        $this->assertCandidateNameComplete($candidate);
        $choiceKey = $this->candidateOptionKey($candidate['hash']);
        $profile = $request->attributes->get('user_profile');
        $this->assertVoteEligible($processId, $profile, $scopeLevel);
        if ($this->rateLimited('vote-challenge:'.$profile->user_id, 10)) return response()->json(['message' => 'تعداد درخواست‌ها زیاد است؛ کمی بعد دوباره تلاش کنید.'], 429);
        $credential = DB::table('user_biometric_credentials')->where('user_id', $profile->user_id)->where('is_active', true)->first(['credential_id']);
        if ($credential === null) throw new UnprocessableEntityHttpException('برای این حساب ورود بیومتریک فعال نیست.');
        $challengeId = (string) Str::uuid();
        $challenge = random_bytes(32);
        $context = hash('sha256', $this->canonical(['process_id' => $processId, 'choice_key' => $choiceKey, 'given_name' => $data['given_name'], 'family_name' => $data['family_name'], 'father_name' => $data['father_name']]), true);
        DB::table('user_biometric_challenges')->insert([
            'challenge_id' => $challengeId, 'user_id' => $profile->user_id, 'credential_id' => $credential->credential_id,
            'purpose' => 'vote', 'challenge' => $challenge, 'context_hash' => $context,
            'expires_at' => now()->addMinutes(5), 'created_at' => now(),
        ]);
        return response()->json(['data' => [
            'challenge_id' => $challengeId,
            'credential_id' => $this->uuidFromBinary((string) $credential->credential_id),
            'signed_payload' => 'vetoapp-biometric-v1|vote|'.$challengeId.'|'.$this->base64Url($challenge).'|'.$this->base64Url($context),
        ]]);
    }

    public function confirmation(Request $request, string $electionType, int $processId): JsonResponse
    {
        $scopeLevel = $this->scopeLevel($electionType);
        $data = $request->validate([
            'given_name' => ['required', 'string', 'min:1', 'max:100'],
            'family_name' => ['required', 'string', 'min:1', 'max:120'],
            'father_name' => ['required', 'string', 'min:1', 'max:100'],
            'idempotency_key' => ['required', 'uuid'],
            'confirmation_method' => ['required', 'in:password,biometric'],
            'password' => ['required_if:confirmation_method,password', 'nullable', 'string', 'max:255'],
            'challenge_id' => ['required_if:confirmation_method,biometric', 'nullable', 'uuid'],
            'credential_id' => ['required_if:confirmation_method,biometric', 'nullable', 'uuid'],
            'signature' => ['required_if:confirmation_method,biometric', 'nullable', 'string', 'max:2048'],
        ]);
        $candidate = $this->candidates->normalize($data['given_name'], $data['family_name'], $data['father_name']);
        $this->assertCandidateNameComplete($candidate);
        $data['choice_key'] = $this->candidateOptionKey($candidate['hash']);
        $profile = $request->attributes->get('user_profile');
        $this->assertElectionCategoryProcess($processId, $scopeLevel);
        if ($this->rateLimited('vote-confirm:'.$profile->user_id, 12)) return response()->json(['message' => 'تعداد درخواست‌ها زیاد است؛ کمی بعد دوباره تلاش کنید.'], 429);
        $account = $profile->account()->first();
        if ($account === null || $account->account_status !== 'Active' || ($account->locked_until !== null && $account->locked_until->isFuture())) {
            throw new UnprocessableEntityHttpException('حساب کاربری در وضعیت مجاز برای رأی‌دادن نیست.');
        }
        if ($data['confirmation_method'] === 'password' && ! Hash::check($data['password'], (string) $account->password_hash)) {
            throw ValidationException::withMessages(['password' => ['رمز عبور صحیح نیست.']]);
        }
        if ($data['confirmation_method'] === 'biometric' && ! $this->consumeBiometricChallenge($data, $processId, (string) $data['choice_key'], (int) $profile->user_id)) {
            throw new UnprocessableEntityHttpException('تأیید بیومتریک معتبر نیست یا منقضی شده است.');
        }

        $identity = $this->voterIdentityKey((string) $profile->national_id_hash);
        $issueKey = hash('sha256', str_replace('-', '', $data['idempotency_key']), true);
        $selectionHash = $this->candidateSelectionHash($processId, $data);
        $rawToken = $this->makeVoteToken($processId, $data['choice_key'], $identity, $data['idempotency_key'], $selectionHash);
        $tokenHash = hash('sha256', $rawToken, true);
        $record = DB::transaction(function () use ($processId, $scopeLevel, $identity, $issueKey, $tokenHash, $profile): object {
            $prior = DB::table('vote_tokens')->where('issuance_idempotency_key', $issueKey)->lockForUpdate()->first();
            if ($prior !== null) {
                if (! hash_equals((string) $prior->participant_identity_key, $identity) || ! hash_equals((string) $prior->token_hash, $tokenHash)
                    || ! in_array($prior->token_state_code, ['ISSUED', 'USED'], true)) {
                    throw new ConflictHttpException('این کلید تکرار برای صدور توکن دیگری استفاده شده یا توکن منقضی است.');
                }
                if ($prior->token_state_code === 'ISSUED' && now()->greaterThanOrEqualTo($prior->expires_at)) {
                    $eligibleProcess = $this->assertVoteEligible($processId, $profile, $scopeLevel);
                    DB::table('vote_tokens')->where('vote_token_id', $prior->vote_token_id)->update([
                        'issued_at' => now(),
                        'expires_at' => now()->addSeconds(max(120, min(600, (int) $eligibleProcess->vote_token_ttl_seconds))),
                    ]);
                    $prior = DB::table('vote_tokens')->where('vote_token_id', $prior->vote_token_id)->first();
                }
                return $prior;
            }
            $eligibleProcess = $this->assertVoteEligible($processId, $profile, $scopeLevel);
            DB::table('vote_tokens')->where('process_id', $processId)->where('participant_identity_key', $identity)
                ->where('token_state_code', 'ISSUED')->update(['token_state_code' => 'REVOKED', 'revoked_at' => now()]);
            $id = DB::table('vote_tokens')->insertGetId([
                'process_id' => $processId, 'participant_identity_key' => $identity, 'token_hash' => $tokenHash,
                'token_state_code' => 'ISSUED', 'issued_at' => now(),
                'expires_at' => now()->addSeconds(max(120, min(600, (int) $eligibleProcess->vote_token_ttl_seconds))),
                'consumed_at' => null, 'revoked_at' => null, 'issuance_idempotency_key' => $issueKey,
            ]);
            return DB::table('vote_tokens')->where('vote_token_id', $id)->first();
        }, 3);
        return response()->json(['data' => [
            'vote_token' => $rawToken,
            'expires_at' => $record->expires_at,
        ]]);
    }

    public function cast(Request $request, string $electionType, int $processId): JsonResponse
    {
        $scopeLevel = $this->scopeLevel($electionType);
        $data = $request->validate([
            'vote_token' => ['required', 'string', 'max:1024'],
            'given_name' => ['required', 'string', 'min:1', 'max:100'],
            'family_name' => ['required', 'string', 'min:1', 'max:120'],
            'father_name' => ['required', 'string', 'min:1', 'max:100'],
            'issuance_idempotency_key' => ['required', 'uuid'], 'submission_idempotency_key' => ['required', 'uuid'],
        ]);
        $candidate = $this->candidates->normalize($data['given_name'], $data['family_name'], $data['father_name']);
        $this->assertCandidateNameComplete($candidate);
        $data['choice_key'] = $this->candidateOptionKey($candidate['hash']);
        $profile = $request->attributes->get('user_profile');
        $this->assertElectionCategoryProcess($processId, $scopeLevel);
        if ($this->rateLimited('vote-cast:'.$profile->user_id, 20)) return response()->json(['message' => 'تعداد درخواست‌ها زیاد است؛ کمی بعد دوباره تلاش کنید.'], 429);
        $identity = $this->voterIdentityKey((string) $profile->national_id_hash);
        $selectionHash = $this->candidateSelectionHash($processId, $data);
        $submissionKey = hash('sha256', str_replace('-', '', $data['submission_idempotency_key']), true);
        $claims = $this->parseVoteToken($data['vote_token']);
        if ($claims === null || (int) ($claims['process_id'] ?? 0) !== $processId || ($claims['choice_key'] ?? null) !== $data['choice_key']
            || ! hash_equals((string) ($claims['identity'] ?? ''), bin2hex($identity))
            || ! hash_equals((string) ($claims['issuance_idempotency_key'] ?? ''), $data['issuance_idempotency_key'])
            || ! hash_equals((string) ($claims['selection_hash'] ?? ''), $selectionHash)) {
            throw new UnprocessableEntityHttpException('توکن رأی معتبر نیست یا به این انتخاب تعلق ندارد.');
        }
        $issuanceKey = hash('sha256', str_replace('-', '', $data['issuance_idempotency_key']), true);
        $issuedToken = DB::table('vote_tokens')->where('process_id', $processId)
            ->where('participant_identity_key', $identity)->where('issuance_idempotency_key', $issuanceKey)->first();
        if ($issuedToken === null || ! in_array($issuedToken->token_state_code, ['ISSUED', 'USED'], true)
            || ! hash_equals((string) $issuedToken->token_hash, hash('sha256', $data['vote_token'], true))) {
            throw new UnprocessableEntityHttpException('توکن رأی برای این حساب و درخواست صادر نشده است.');
        }
        $existing = DB::table('ballot_box_entries')->where('ballot_submission_idempotency_key', $submissionKey)->first();
        if ($existing !== null) {
            $receipt = DB::table('digital_receipts')->join('digital_receipt_vote_details as vd', 'vd.digital_receipt_id', '=', 'digital_receipts.digital_receipt_id')
                ->where('vd.ballot_box_entry_id', $existing->ballot_box_entry_id)->first();
            if ($receipt === null || (int) $existing->process_id !== $processId || $existing->ballot_option_key !== $data['choice_key']
                || $issuedToken->token_state_code !== 'USED'
                || (int) $receipt->beneficiary_user_account_id !== (int) $profile->user_id) throw new ConflictHttpException('کلید تکرار درخواست قبلاً برای عملیات دیگری استفاده شده است.');
            return response()->json(['data' => $this->voteReceiptResponse($receipt, (int) $existing->sequence_no)]);
        }

        try {
            $receipt = DB::transaction(function () use ($request, $profile, $processId, $scopeLevel, $data, $identity, $submissionKey, $issuanceKey): object {
                $process = DB::table('processes as p')->join('process_shard_placements as pl', function ($join): void {
                    $join->on('pl.process_id', '=', 'p.process_id')->where('pl.placement_state_code', '=', 'ACTIVE');
                })->join('process_states as ps', function ($join): void {
                    $join->on('ps.process_id', '=', 'p.process_id')->whereNull('ps.current_state_completed_at');
                })->where('p.process_id', $processId)->where('p.process_type_code', 'Election')
                    ->where('p.target_geographic_level_code', $scopeLevel)->lockForUpdate()
                    ->first(['p.*', 'ps.current_state_code']);
                if ($process === null || $process->current_state_code !== 'VoteCasting' || now()->greaterThanOrEqualTo($process->voting_closes_at)) {
                    throw new ConflictHttpException('مهلت رأی‌گیری پایان یافته یا رأی‌گیری فعال نیست.');
                }
                if (! $this->profileMatchesTarget($process, $profile)) throw new ConflictHttpException('حوزهٔ جغرافیایی شما واجد شرایط این انتخابات نیست.');
                $prior = DB::table('ballot_box_entries')->where('ballot_submission_idempotency_key', $submissionKey)->first();
                if ($prior !== null) {
                    $priorReceipt = DB::table('digital_receipts')->join('digital_receipt_vote_details as vd', 'vd.digital_receipt_id', '=', 'digital_receipts.digital_receipt_id')
                        ->where('vd.ballot_box_entry_id', $prior->ballot_box_entry_id)->first();
                    if ($priorReceipt !== null && (int) $prior->process_id === $processId && $prior->ballot_option_key === $data['choice_key']
                        && (int) $priorReceipt->beneficiary_user_account_id === (int) $profile->user_id) return (object) ['receipt' => $priorReceipt, 'sequence_no' => (int) $prior->sequence_no];
                    throw new ConflictHttpException('کلید تکرار درخواست قبلاً ثبت شده است.');
                }
                $normalized = $this->candidates->normalize($data['given_name'], $data['family_name'], $data['father_name']);
                $candidate = DB::table('election_candidates')->where('process_id', $processId)
                    ->where('normalized_identity_hash', $normalized['hash'])->lockForUpdate()->first();
                if ($candidate === null) {
                    $candidateId = DB::table('election_candidates')->insertGetId([
                        'process_id' => $processId, 'normalized_identity_hash' => $normalized['hash'],
                        'normalized_given_name' => $normalized['given'], 'normalized_family_name' => $normalized['family'],
                        'normalized_father_name' => $normalized['father'], 'display_given_name' => $data['given_name'],
                        'display_family_name' => $data['family_name'], 'display_father_name' => $data['father_name'],
                        'created_at' => now(),
                    ]);
                    $candidate = DB::table('election_candidates')->where('election_candidate_id', $candidateId)->first();
                }
                $variantHash = hash('sha256', $this->canonical(['given_name' => $data['given_name'], 'family_name' => $data['family_name'], 'father_name' => $data['father_name']]), true);
                DB::table('election_candidate_name_variants')->insertOrIgnore([
                    'process_id' => $processId, 'election_candidate_id' => $candidate->election_candidate_id,
                    'given_name' => $data['given_name'], 'family_name' => $data['family_name'], 'father_name' => $data['father_name'],
                    'variant_hash' => $variantHash, 'created_at' => now(),
                ]);
                $option = DB::table('process_ballot_options')->where('process_id', $processId)->where('option_key', $data['choice_key'])->where('is_active', true)->first();
                if ($option === null) {
                    DB::table('process_ballot_options')->insert([
                        'process_id' => $processId, 'option_key' => $data['choice_key'], 'option_type_code' => 'CANDIDATE',
                        'election_candidate_id' => $candidate->election_candidate_id,
                        'display_label' => trim($data['given_name'].' '.$data['family_name'].'، فرزند '.$data['father_name']),
                        'candidate_given_name' => $data['given_name'], 'candidate_family_name' => $data['family_name'],
                        'candidate_father_name' => $data['father_name'], 'is_active' => true, 'created_at' => now(),
                    ]);
                    $option = DB::table('process_ballot_options')->where('process_id', $processId)->where('option_key', $data['choice_key'])->first();
                }
                $token = DB::table('vote_tokens')->where('process_id', $processId)->where('participant_identity_key', $identity)
                    ->where('issuance_idempotency_key', $issuanceKey)->lockForUpdate()->first();
                $expectedTokenHash = hash('sha256', $data['vote_token'], true);
                if ($token === null || ! hash_equals((string) $token->token_hash, $expectedTokenHash) || $token->token_state_code !== 'ISSUED' || now()->greaterThanOrEqualTo($token->expires_at)) {
                    throw new ConflictHttpException('توکن رأی مصرف شده، منقضی یا نامعتبر است.');
                }
                if (DB::table('voter_participations')->where('process_id', $processId)->where('participant_identity_key', $identity)->exists()) {
                    throw new ConflictHttpException('رأی شما پیش‌تر برای این انتخابات ثبت شده است.');
                }
                $genesisHash = hash('sha256', 'vetoapp-chain-genesis|SHA-256-TLV1-DOMAIN02', true);
                DB::table('process_sequence_allocators')->insertOrIgnore([
                    'process_id' => $processId, 'next_sequence_no' => 1, 'last_hash' => $genesisHash,
                    'hash_version' => 'SHA-256-TLV1-DOMAIN02', 'last_appended_at' => now(),
                ]);
                $allocator = DB::table('process_sequence_allocators')->where('process_id', $processId)->lockForUpdate()->first();
                if ($allocator->hash_version !== 'SHA-256-TLV1-DOMAIN02') throw new ConflictHttpException('نسخهٔ زنجیرهٔ رأی با نسخهٔ مجاز این سامانه هم‌خوان نیست.');
                $sequence = (int) $allocator->next_sequence_no;
                $previousHash = (string) $allocator->last_hash;
                $now = now()->utc();
                $canonicalPayload = $this->voteSelectionPayload($process, $data['choice_key'], $data);
                if (strlen($canonicalPayload) > 512) throw new \RuntimeException('Canonical vote payload exceeds the database field size.');
                $recordedAt = $now->format('Y-m-d\TH:i:s.v\Z');
                $chainInput = $this->tlv(1, $this->uint64(1))
                    .$this->tlv(2, $this->uint64($processId))
                    .$this->tlv(3, $this->uint64($sequence))
                    .$this->tlv(4, $previousHash)
                    .$this->tlv(5, $canonicalPayload)
                    .$this->tlv(6, $this->uint64((int) $profile->country_id))
                    .$this->tlv(7, $this->uint64((int) $profile->province_id))
                    .$this->tlv(8, $this->uint64((int) $profile->county_id))
                    .$this->tlv(9, $this->uint64((int) $profile->settlement_id))
                    .$this->tlv(10, $recordedAt);
                $currentHash = hash('sha256', "\x02".$chainInput, true);
                $entryId = DB::table('ballot_box_entries')->insertGetId([
                    'process_id' => $processId, 'sequence_no' => $sequence, 'previous_hash' => $previousHash,
                    'current_hash' => $currentHash, 'ballot_option_key' => $data['choice_key'],
                    'election_candidate_id' => $candidate->election_candidate_id,
                    'canonical_vote_payload' => $canonicalPayload, 'ballot_submission_idempotency_key' => $submissionKey,
                    'recorded_at' => $now, 'country_id' => $profile->country_id, 'province_id' => $profile->province_id,
                    'county_id' => $profile->county_id, 'settlement_id' => $profile->settlement_id,
                ]);
                DB::table('process_sequence_allocators')->where('process_id', $processId)->update([
                    'next_sequence_no' => $sequence + 1, 'last_hash' => $currentHash,
                    'last_appended_at' => $now, 'hash_version' => 'SHA-256-TLV1-DOMAIN02',
                ]);
                DB::table('voter_participations')->insert([
                    'process_id' => $processId, 'participant_identity_key' => $identity, 'participated_at' => $now,
                    'country_id' => $profile->country_id, 'province_id' => $profile->province_id,
                    'county_id' => $profile->county_id, 'settlement_id' => $profile->settlement_id,
                ]);
                DB::table('vote_tokens')->where('vote_token_id', $token->vote_token_id)->update(['token_state_code' => 'USED', 'consumed_at' => $now]);
                DB::table('process_projection_outbox_events')->insert([
                    'process_id' => $processId, 'event_type_code' => 'VOTE_COMMITTED', 'source_record_id' => $entryId,
                    'event_key' => hash('sha256', 'VOTE_COMMITTED|'.$processId.'|'.$entryId, true),
                    'payload' => json_encode(['ballot_box_entry_id' => $entryId], JSON_THROW_ON_ERROR),
                    'created_at' => $now, 'processed_at' => null, 'attempts' => 0,
                ]);

                $receiptNumber = random_bytes(32);
                $issuedAt = $now->format('Y-m-d H:i:s.v');
                $keyId = (string) config('services.process_receipts.key_id');
                $candidateLabel = trim($data['given_name'].' '.$data['family_name'].'، فرزند '.$data['father_name']);
                $payload = [
                    'domain' => 'vetoapp-vote-receipt-v1', 'payload_version' => 2, 'receipt_type_code' => 'VOTE',
                    'receipt_number' => bin2hex($receiptNumber), 'process_id' => (string) $processId,
                    'process_type_code' => 'Election', 'event_title' => $process->title,
                    'issued_at' => $now->format('Y-m-d\TH:i:s.v\Z'), 'key_id' => $keyId,
                    'sequence_no' => $sequence, 'ballot_commitment' => $this->base64Url($currentHash),
                    'ballot_choice_key' => $data['choice_key'], 'ballot_choice_label' => $candidateLabel,
                ];
                $receiptHash = hash('sha256', $this->canonical($payload), true);
                $signed = $this->receipts->sign($receiptHash);
                $receiptId = DB::table('digital_receipts')->insertGetId([
                    'process_id' => $processId, 'beneficiary_user_account_id' => $profile->user_id,
                    'participant_identity_key' => null, 'support_idempotency_key' => null, 'receipt_type_code' => 'VOTE',
                    'process_type_code' => 'Election', 'event_title_snapshot' => $process->title,
                    'receipt_number' => $receiptNumber, 'payload_version' => 2, 'receipt_hash' => $receiptHash,
                    'signature_value' => $signed['signature'], 'key_id' => $signed['key_id'], 'issued_at' => $issuedAt,
                ]);
                DB::table('digital_receipt_vote_details')->insert([
                    'digital_receipt_id' => $receiptId, 'ballot_box_entry_id' => $entryId,
                    'election_candidate_id' => $candidate->election_candidate_id,
                    'candidate_given_name_snapshot' => $data['given_name'], 'candidate_family_name_snapshot' => $data['family_name'],
                    'candidate_father_name_snapshot' => $data['father_name'],
                    'vote_payload_version' => 1, 'ballot_choice_key_snapshot' => $data['choice_key'],
                    'ballot_choice_label_snapshot' => $candidateLabel, 'ballot_commitment' => $currentHash, 'created_at' => $now,
                ]);
                $record = DB::table('digital_receipts')->where('digital_receipt_id', $receiptId)->first();
                return (object) ['receipt' => $record, 'sequence_no' => $sequence];
            }, 3);
        } catch (\Illuminate\Database\QueryException $exception) {
            if (! in_array((int) ($exception->errorInfo[1] ?? 0), [1062, 23000], true)) throw $exception;
            $existing = DB::table('ballot_box_entries')->where('ballot_submission_idempotency_key', $submissionKey)->first();
            if ($existing !== null) {
                $priorReceipt = DB::table('digital_receipts')->join('digital_receipt_vote_details as vd', 'vd.digital_receipt_id', '=', 'digital_receipts.digital_receipt_id')
                    ->where('vd.ballot_box_entry_id', $existing->ballot_box_entry_id)->first();
                if ($priorReceipt !== null && (int) $existing->process_id === $processId && $existing->ballot_option_key === $data['choice_key']
                    && (int) $priorReceipt->beneficiary_user_account_id === (int) $profile->user_id) {
                    return response()->json(['data' => $this->voteReceiptResponse($priorReceipt, (int) $existing->sequence_no)]);
                }
            }
            throw new ConflictHttpException('درخواست رأی هم‌زمان ثبت شده یا تکراری است.');
        }
        return response()->json(['data' => $this->voteReceiptResponse($receipt->receipt, (int) $receipt->sequence_no)], 201);
    }

    private function processQuery(string $kind, ?int $scopeLevel = null): Builder
    {
        $query = DB::table('processes as p')
            ->join('process_shard_placements as pl', function ($join): void { $join->on('pl.process_id', '=', 'p.process_id')->where('pl.placement_state_code', 'ACTIVE'); })
            ->join('process_states as ps', function ($join): void { $join->on('ps.process_id', '=', 'p.process_id')->whereNull('ps.current_state_completed_at'); })
            ->join('process_lifecycle_policy_versions as policy', 'policy.process_lifecycle_policy_version_id', '=', 'p.process_lifecycle_policy_version_id')
            ->leftJoin('countries as c', fn ($join) => $join->on('c.country_id', '=', 'p.target_geographic_id')->where('p.target_geographic_level_code', 1))
            ->leftJoin('provinces as pr', fn ($join) => $join->on('pr.province_id', '=', 'p.target_geographic_id')->where('p.target_geographic_level_code', 2))
            ->leftJoin('counties as co', fn ($join) => $join->on('co.county_id', '=', 'p.target_geographic_id')->where('p.target_geographic_level_code', 3))
            ->leftJoin('settlements as s', fn ($join) => $join->on('s.settlement_id', '=', 'p.target_geographic_id')->where('p.target_geographic_level_code', 4))
            ->where('p.process_type_code', 'Election')
            ->select(['p.*', 'ps.current_state_code', 'ps.current_state_started_at', 'policy.waiting_period_seconds',
                'policy.voting_period_seconds', 'policy.publication_delay_seconds',
                DB::raw("CASE p.target_geographic_level_code WHEN 1 THEN 'کشور' WHEN 2 THEN 'استان' WHEN 3 THEN 'شهرستان' ELSE 'شهر یا روستا' END AS geographic_label"),
                DB::raw('COALESCE(c.name_fa, pr.name_fa, co.name_fa, s.name_fa) AS geographic_name')]);
        if ($scopeLevel !== null) $query->where('p.target_geographic_level_code', $scopeLevel);
        return match ($kind) {
            'scheduled' => $query->where('ps.current_state_code', 'Waiting'),
            'eligible', 'live' => $query->where('ps.current_state_code', 'VoteCasting')->where('p.voting_closes_at', '>', now()),
            'finalized' => $query->where('ps.current_state_code', 'Finalized')->whereExists(fn ($q) => $q->selectRaw('1')->from('process_merkle_trees as mt')->whereColumn('mt.process_id', 'p.process_id')->where('mt.checkpoint_kind', 'FINAL')->whereNotNull('mt.published_at')),
            default => $query,
        };
    }

    private function summary(object $row, string $kind): array
    {
        $expectedOpen = $row->current_state_code === 'Waiting'
            ? Carbon::parse($row->current_state_started_at)->addSeconds((int) $row->waiting_period_seconds)
            : null;
        $expectedClose = $expectedOpen?->copy()->addSeconds((int) $row->voting_period_seconds);
        return [
            'process_id' => (int) $row->process_id, 'title' => $row->title, 'state_code' => $row->current_state_code,
            'state_label' => $this->stateLabel((string) $row->current_state_code),
            'geographic_level_code' => (int) $row->target_geographic_level_code, 'geographic_id' => (int) $row->target_geographic_id,
            'geographic_label' => $row->geographic_label, 'geographic_name' => $row->geographic_name,
            'expected_voting_opens_at' => $expectedOpen?->toISOString(), 'expected_voting_closes_at' => $expectedClose?->toISOString(),
            'voting_opens_at' => $row->voting_opens_at, 'voting_closes_at' => $row->voting_closes_at,
        ];
    }

    private function filterEligible(Builder $query, object $profile): void
    {
        $account = $profile->account()->first();
        if ($account === null || $account->account_status !== 'Active' || ($account->locked_until !== null && $account->locked_until->isFuture())) {
            $query->whereRaw('1 = 0');
            return;
        }
        $scopeId = fn ($row) => match ((int) $row->target_geographic_level_code) {
            1 => (int) $profile->country_id, 2 => (int) $profile->province_id,
            3 => (int) $profile->county_id, default => (int) $profile->settlement_id,
        };
        $query->where(function ($eligible) use ($profile, $scopeId): void {
            foreach ([1, 2, 3, 4] as $level) $eligible->orWhere(fn ($branch) => $branch->where('p.target_geographic_level_code', $level)->where('p.target_geographic_id', $scopeId((object) ['target_geographic_level_code' => $level])));
        });
        $identity = $this->voterIdentityKey((string) $profile->national_id_hash);
        $query->whereNotExists(fn ($sub) => $sub->selectRaw('1')->from('voter_participations as vp')->whereColumn('vp.process_id', 'p.process_id')->where('vp.participant_identity_key', $identity));
    }

    private function assertVoteEligible(int $processId, object $profile, int $scopeLevel): object
    {
        $account = $profile->account()->first();
        if ($account === null || $account->account_status !== 'Active' || ($account->locked_until !== null && $account->locked_until->isFuture())) {
            throw new ConflictHttpException('حساب کاربری در وضعیت مجاز برای رأی‌دادن نیست.');
        }
        $process = $this->processQuery('live', $scopeLevel)->where('p.process_id', $processId)->first();
        if ($process === null || ! $this->profileMatchesTarget($process, $profile)) throw new ConflictHttpException('این انتخابات فعال نیست یا حوزهٔ جغرافیایی شما واجد شرایط نیست.');
        $identity = $this->voterIdentityKey((string) $profile->national_id_hash);
        if (DB::table('voter_participations')->where('process_id', $processId)->where('participant_identity_key', $identity)->exists()) throw new ConflictHttpException('رأی شما پیش‌تر ثبت شده است.');
        return $process;
    }

    private function profileMatchesTarget(object $process, object $profile): bool
    {
        $userGeo = match ((int) $process->target_geographic_level_code) {
            1 => (int) $profile->country_id, 2 => (int) $profile->province_id,
            3 => (int) $profile->county_id, 4 => (int) $profile->settlement_id,
            default => 0,
        };
        return $userGeo === (int) $process->target_geographic_id;
    }

    private function filterWithinGeography(Builder $query, int $level, int $id): void
    {
        $query->where(function ($scope) use ($level, $id): void {
            $scope->where(fn ($q) => $q->where('p.target_geographic_level_code', $level)->where('p.target_geographic_id', $id));
            if ($level === 1) {
                $scope->orWhereExists(fn ($q) => $q->selectRaw('1')->from('provinces as x')->whereColumn('x.province_id', 'p.target_geographic_id')->where('p.target_geographic_level_code', 2)->where('x.country_id', $id))
                    ->orWhereExists(fn ($q) => $q->selectRaw('1')->from('counties as x')->join('provinces as y', 'y.province_id', '=', 'x.province_id')->whereColumn('x.county_id', 'p.target_geographic_id')->where('p.target_geographic_level_code', 3)->where('y.country_id', $id))
                    ->orWhereExists(fn ($q) => $q->selectRaw('1')->from('settlements as x')->join('counties as y', 'y.county_id', '=', 'x.county_id')->join('provinces as z', 'z.province_id', '=', 'y.province_id')->whereColumn('x.settlement_id', 'p.target_geographic_id')->where('p.target_geographic_level_code', 4)->where('z.country_id', $id));
            } elseif ($level === 2) {
                $scope->orWhereExists(fn ($q) => $q->selectRaw('1')->from('counties as x')->whereColumn('x.county_id', 'p.target_geographic_id')->where('p.target_geographic_level_code', 3)->where('x.province_id', $id))
                    ->orWhereExists(fn ($q) => $q->selectRaw('1')->from('settlements as x')->join('counties as y', 'y.county_id', '=', 'x.county_id')->whereColumn('x.settlement_id', 'p.target_geographic_id')->where('p.target_geographic_level_code', 4)->where('y.province_id', $id));
            } elseif ($level === 3) {
                $scope->orWhereExists(fn ($q) => $q->selectRaw('1')->from('settlements as x')->whereColumn('x.settlement_id', 'p.target_geographic_id')->where('p.target_geographic_level_code', 4)->where('x.county_id', $id));
            }
        });
    }

    private function assertGeographyWithinProcess(object $process, int $level, int $id): void
    {
        $candidate = DB::query()->selectRaw('1 as valid')->fromSub(DB::table('processes as p')->where('p.process_id', $process->process_id), 'p');
        $this->filterWithinGeography($candidate, $level, $id);
        if (! $candidate->exists()) throw ValidationException::withMessages(['geographic_id' => ['حوزهٔ انتخابی در دامنهٔ این انتخابات نیست.']]);
    }

    private function resultChildren(int $processId, int $parentLevel, int $parentId, int $childLevel): array
    {
        [$table, $idCol, $parentCol] = match ($childLevel) {
            2 => ['provinces', 'province_id', 'country_id'], 3 => ['counties', 'county_id', 'province_id'],
            4 => ['settlements', 'settlement_id', 'county_id'], default => ['', '', ''],
        };
        if ($table === '') return [];
        $geo = DB::table($table.' as g')->leftJoin('process_geographic_counters as c', function ($join) use ($idCol, $processId, $childLevel): void {
            $join->on('c.geographic_id', '=', 'g.'.$idCol)->where('c.process_id', $processId)->where('c.counter_type', 'VOTE')->where('c.geographic_level_code', $childLevel)->where('c.ballot_choice_key', 'YES');
        });
        if ($parentLevel === 1 && $childLevel === 2) $geo->where('g.country_id', $parentId);
        elseif ($parentLevel === 2 && $childLevel === 3) $geo->where('g.province_id', $parentId);
        elseif ($parentLevel === 3 && $childLevel === 4) $geo->where('g.county_id', $parentId);
        else return [];
        return $geo->leftJoin('process_geographic_counters as n', function ($join) use ($processId, $childLevel): void {
            $join->on('n.geographic_id', '=', 'c.geographic_id')->on('n.geographic_level_code', '=', 'c.geographic_level_code')->where('n.process_id', $processId)->where('n.counter_type', 'VOTE')->where('n.ballot_choice_key', 'NO');
        })->where(function ($q): void { $q->where('c.counter_value', '>', 0)->orWhere('n.counter_value', '>', 0); })->orderBy('g.name_fa')->limit(300)
            ->get(['g.'.$idCol.' as geographic_id', 'g.name_fa as name', 'c.counter_value as YES', 'n.counter_value as NO'])
            ->map(fn ($r) => ['geographic_id' => (int) $r->geographic_id, 'name' => $r->name, 'geographic_label' => $this->levelLabel($childLevel), 'YES' => (int) $r->YES, 'NO' => (int) ($r->NO ?? 0)])->all();
    }

    private function consumeBiometricChallenge(array $data, int $processId, string $choice, int $userId): bool
    {
        return DB::transaction(function () use ($data, $processId, $choice, $userId): bool {
            $challenge = DB::table('user_biometric_challenges')->where('challenge_id', $data['challenge_id'])->lockForUpdate()->first();
            $credentialId = hex2bin(str_replace('-', '', $data['credential_id'])) ?: '';
            $expectedContext = hash('sha256', $this->canonical(['process_id' => $processId, 'choice_key' => $choice, 'given_name' => $data['given_name'], 'family_name' => $data['family_name'], 'father_name' => $data['father_name']]), true);
            if ($challenge === null || $challenge->purpose !== 'vote' || (int) $challenge->user_id !== $userId
                || $challenge->credential_id === null || ! hash_equals((string) $challenge->credential_id, $credentialId)
                || $challenge->context_hash === null || ! hash_equals((string) $challenge->context_hash, $expectedContext)
                || $challenge->consumed_at !== null || now()->greaterThanOrEqualTo($challenge->expires_at)) return false;
            DB::table('user_biometric_challenges')->where('challenge_id', $data['challenge_id'])->update(['consumed_at' => now()]);
            $credential = DB::table('user_biometric_credentials')->where('user_id', $userId)->where('credential_id', $credentialId)->where('is_active', true)->first();
            $signature = $this->base64UrlDecode($data['signature']);
            $payload = 'vetoapp-biometric-v1|vote|'.$data['challenge_id'].'|'.$this->base64Url((string) $challenge->challenge).'|'.$this->base64Url((string) $challenge->context_hash);
            if ($credential === null || $signature === null || ! $this->verifyP256((string) $credential->public_key, $signature, $payload)) return false;
            DB::table('user_biometric_credentials')->where('biometric_credential_id', $credential->biometric_credential_id)->increment('sign_count', 1, ['last_used_at' => now(), 'updated_at' => now()]);
            return true;
        }, 3);
    }

    private function makeVoteToken(int $processId, string $choice, string $identity, string $idempotency, string $selectionHash): string
    {
        $claims = ['process_id' => $processId, 'choice_key' => $choice, 'identity' => bin2hex($identity), 'issuance_idempotency_key' => $idempotency, 'selection_hash' => $selectionHash];
        $body = $this->base64Url($this->canonical($claims));
        return $body.'.'.$this->base64Url(hash_hmac('sha256', 'vote-token-v1|'.$body, $this->tokenKey(), true));
    }

    private function parseVoteToken(string $token): ?array
    {
        $parts = explode('.', $token);
        if (count($parts) !== 2) return null;
        $expected = $this->base64Url(hash_hmac('sha256', 'vote-token-v1|'.$parts[0], $this->tokenKey(), true));
        if (! hash_equals($expected, $parts[1])) return null;
        $decoded = $this->base64UrlDecode($parts[0]);
        if ($decoded === null) return null;
        try { $claims = json_decode($decoded, true, flags: JSON_THROW_ON_ERROR); } catch (\Throwable) { return null; }
        return is_array($claims) ? $claims : null;
    }

    private function tokenKey(): string
    {
        $key = (string) config('app.key');
        if (str_starts_with($key, 'base64:')) $key = base64_decode(substr($key, 7), true) ?: '';
        if (strlen($key) < 32) throw new \RuntimeException('APP_KEY must contain at least 32 bytes to issue vote tokens.');
        return hash_hmac('sha256', 'vetoapp-vote-token-key-v1', $key, true);
    }

    private function voterIdentityKey(string $nationalIdHash): string
    {
        $key = (string) config('services.process_receipts.identity_hmac_key');
        if (strlen($key) < 32) throw new \RuntimeException('PROCESS_IDENTITY_HMAC_KEY is not configured.');
        return hash_hmac('sha256', 'vote-v1|'.bin2hex($nationalIdHash), $key, true);
    }

    private function profileGeographies(object $profile): array { return [1 => (int) $profile->country_id, 2 => (int) $profile->province_id, 3 => (int) $profile->county_id, 4 => (int) $profile->settlement_id]; }
    private function levelLabel(int $level): string { return match ($level) { 1 => 'کشور', 2 => 'استان', 3 => 'شهرستان', default => 'شهر یا روستا' }; }
    private function stateLabel(string $state): string { return match ($state) { 'Waiting' => 'زمان‌بندی‌شده', 'VoteCasting' => 'در حال رأی‌گیری', 'Publishing' => 'در حال انتشار نتیجه', 'Finalized' => 'پایان‌یافته و نهایی', default => $state }; }

    private function voteReceiptResponse(object $receipt, int $sequence): array
    {
        $vote = DB::table('digital_receipt_vote_details')
            ->where('digital_receipt_id', $receipt->digital_receipt_id)
            ->first(['ballot_choice_key_snapshot', 'ballot_choice_label_snapshot', 'candidate_given_name_snapshot', 'candidate_family_name_snapshot', 'candidate_father_name_snapshot']);
        return ['receipt_number' => $this->base64Url((string) $receipt->receipt_number), 'receipt_hash' => $this->base64Url((string) $receipt->receipt_hash),
            'signature' => $this->base64Url((string) $receipt->signature_value), 'key_id' => $receipt->key_id,
            'algorithm' => 'Ed25519', 'issued_at' => $receipt->issued_at, 'process_id' => (string) $receipt->process_id,
            'sequence_no' => $sequence, 'title' => $receipt->event_title_snapshot,
            'choice_key' => $vote?->ballot_choice_key_snapshot,
            'choice_label' => $vote?->ballot_choice_label_snapshot,
            'candidate' => $vote === null ? null : ['given_name' => $vote->candidate_given_name_snapshot, 'family_name' => $vote->candidate_family_name_snapshot, 'father_name' => $vote->candidate_father_name_snapshot]];
    }

    private function canonical(array $value): string { ksort($value); return json_encode($value, JSON_THROW_ON_ERROR | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES); }
    private function voteSelectionPayload(object $process, string $choice, array $candidate): string
    {
        $version = (int) $process->canonical_encoding_version;
        if ($version !== 1) throw new ConflictHttpException('نسخهٔ رمزگذاری برگهٔ رأی پشتیبانی نمی‌شود.');
        $schemaId = (string) $process->ballot_schema_id;
        if (class_exists(\Normalizer::class)) $schemaId = \Normalizer::normalize($schemaId, \Normalizer::FORM_C) ?: $schemaId;
        return $this->tlv(1, $this->uint64($version))
            .$this->tlv(2, $this->uint64((int) $process->process_id))
            .$this->tlv(3, $schemaId)
            .$this->tlv(4, $this->uint64((int) $process->ballot_schema_version))
            .$this->tlv(5, $choice)
            .$this->tlv(6, $this->candidates->normalize($candidate['given_name'], $candidate['family_name'], $candidate['father_name'])['hash'])
            .$this->tlv(7, hash('sha256', $this->canonical(['given_name' => $candidate['given_name'], 'family_name' => $candidate['family_name'], 'father_name' => $candidate['father_name']]), true));
    }

    private function candidateOptionKey(string $normalizedHash): string
    {
        return 'CANDIDATE_'.bin2hex($normalizedHash);
    }

    private function scopeLevel(string $electionType): int
    {
        $levels = ['presidential' => 1, 'governor' => 2, 'county' => 3, 'local' => 4];
        abort_unless(isset($levels[$electionType]), 404);
        return $levels[$electionType];
    }

    private function assertElectionCategoryProcess(int $processId, int $scopeLevel): void
    {
        $matches = DB::table('processes')->where('process_id', $processId)
            ->where('process_type_code', 'Election')->where('target_geographic_level_code', $scopeLevel)->exists();
        abort_unless($matches, 404);
    }

    private function candidateSelectionHash(int $processId, array $candidate): string
    {
        return hash('sha256', $this->canonical([
            'domain' => 'vetoapp-election-candidate-selection-v1', 'process_id' => $processId,
            'given_name' => $candidate['given_name'], 'family_name' => $candidate['family_name'], 'father_name' => $candidate['father_name'],
        ]));
    }
    private function assertCandidateNameComplete(array $candidate): void
    {
        foreach (['given' => 'given_name', 'family' => 'family_name', 'father' => 'father_name'] as $key => $field) {
            if (($candidate[$key] ?? '') === '') {
                throw ValidationException::withMessages([$field => ['این بخش پس از نرمال‌سازی نباید خالی باشد.']]);
            }
        }
    }
    private function tlv(int $tag, string $value): string { return chr($tag).pack('N', strlen($value)).$value; }
    private function uint64(int $value): string { if ($value < 0) throw new \InvalidArgumentException('TLV unsigned values cannot be negative.'); return pack('J', $value); }
    private function rateLimited(string $key, int $max): bool { if (RateLimiter::tooManyAttempts($key, $max)) return true; RateLimiter::hit($key, 60); return false; }
    private function verifyP256(string $der, string $signature, string $payload): bool
    {
        $key = openssl_pkey_get_public("-----BEGIN PUBLIC KEY-----\n".chunk_split(base64_encode($der), 64, "\n")."-----END PUBLIC KEY-----\n");
        if ($key === false) return false;
        $details = openssl_pkey_get_details($key);
        return ($details['type'] ?? null) === OPENSSL_KEYTYPE_EC && in_array($details['ec']['curve_name'] ?? '', ['prime256v1', 'P-256'], true) && openssl_verify($payload, $signature, $key, OPENSSL_ALGO_SHA256) === 1;
    }
    private function uuidFromBinary(string $id): string { $hex = bin2hex($id); return substr($hex, 0, 8).'-'.substr($hex, 8, 4).'-'.substr($hex, 12, 4).'-'.substr($hex, 16, 4).'-'.substr($hex, 20); }
    private function base64Url(string $value): string { return rtrim(strtr(base64_encode($value), '+/', '-_'), '='); }
    private function base64UrlDecode(string $value): ?string { $decoded = base64_decode(strtr($value, '-_', '+/').str_repeat('=', (4 - strlen($value) % 4) % 4), true); return $decoded === false ? null : $decoded; }
}
