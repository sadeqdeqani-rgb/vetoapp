<?php

namespace App\Http\Controllers;

use App\Models\ProcessLifecyclePolicyVersion;
use App\Services\ProcessNotificationRecorder;
use App\Services\ProcessSupportGateService;
use App\Services\ProcessReceiptSigner;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpKernel\Exception\ConflictHttpException;
use Symfony\Component\HttpKernel\Exception\UnprocessableEntityHttpException;

class ImpeachmentProcessController extends Controller
{
    public function __construct(
        private readonly ProcessReceiptSigner $receipts,
        private readonly ProcessNotificationRecorder $notifications,
        private readonly ProcessSupportGateService $supportGate,
    ) {}

    public function index(Request $request, string $office, string $kind): JsonResponse
    {
        $level = $this->officeLevel($office);
        abort_unless(in_array($kind, ['supporting', 'scheduled', 'eligible', 'live', 'finalized'], true), 404);
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
        $query = $this->query($kind, $level);
        if (($data['search'] ?? '') !== '') $query->where('p.title', 'like', '%'.$data['search'].'%');
        if (isset($data['geographic_level_code'])) $this->filterGeography($query, (int) $data['geographic_level_code'], (int) $data['geographic_id']);
        if ($kind === 'eligible') $this->filterEligible($query, $request->attributes->get('user_profile'));
        $page = (int) ($data['page'] ?? 1);
        $perPage = (int) ($data['per_page'] ?? 30);
        $total = (clone $query)->count('p.process_id');
        $rows = $query->orderBy('ps.current_state_started_at')->offset(($page - 1) * $perPage)->limit($perPage)->get();
        return response()->json(['data' => [
            'items' => $rows->map(fn (object $row): array => $this->summary($row))->all(),
            'pagination' => ['page' => $page, 'per_page' => $perPage, 'total' => $total],
        ]]);
    }

    public function show(Request $request, string $office, int $processId): JsonResponse
    {
        $row = $this->query('any', $this->officeLevel($office))->where('p.process_id', $processId)->first();
        abort_if($row === null, 404);
        $profile = $request->attributes->get('user_profile');
        $identity = $this->identity((string) $profile->national_id_hash);
        $data = $this->summary($row);
        $data['has_supported'] = DB::table('support_participations')->where('process_id', $processId)->where('supporter_identity_key', $identity)->exists();
        $data['already_voted'] = DB::table('voter_participations')->where('process_id', $processId)->where('participant_identity_key', $identity)->exists();
        $data['eligible_geography_matches'] = $this->profileMatches($row, $profile);
        $data['can_support'] = $row->current_state_code === 'Supporting' && $data['eligible_geography_matches'] && ! $data['has_supported'];
        $data['can_vote'] = $row->current_state_code === 'VoteCasting'
            && $row->voting_closes_at !== null && Carbon::parse($row->voting_closes_at)->isFuture()
            && $data['eligible_geography_matches'] && ! $data['already_voted'];
        return response()->json(['data' => $data]);
    }

    public function current(Request $request, string $office): JsonResponse
    {
        $profile = $request->attributes->get('user_profile');
        $level = $this->officeLevel($office);
        $row = $this->query('any', $level)->where('p.target_geographic_id', $this->profileGeoId($profile, $level))
            ->whereIn('ps.current_state_code', ['Supporting', 'Waiting', 'VoteCasting', 'Publishing'])->first();
        return response()->json(['data' => ['process' => $row === null ? null : $this->summary($row)]]);
    }

    /** First request and its initial support are committed in one transaction. */
    public function requestImpeachment(Request $request, string $office): JsonResponse
    {
        $level = $this->officeLevel($office);
        $data = $request->validate([
            'idempotency_key' => ['required', 'uuid'],
            'confirmation_method' => ['required', 'in:password'],
            'password' => ['required', 'string', 'max:255'],
        ]);
        $profile = $request->attributes->get('user_profile');
        $this->confirmAccount($profile, $data['password']);
        $geoId = $this->profileGeoId($profile, $level);
        $identity = $this->identity((string) $profile->national_id_hash);
        $idempotency = hash('sha256', str_replace('-', '', $data['idempotency_key']), true);
        if ($this->limited('impeachment-request:'.$profile->user_id, 10)) return response()->json(['message' => 'تعداد درخواست‌ها زیاد است؛ کمی بعد دوباره تلاش کنید.'], 429);

        $receipt = DB::transaction(function () use ($profile, $level, $geoId, $identity, $idempotency): object {
            $prior = DB::table('support_participations')->where('idempotency_key', $idempotency)->first();
            if ($prior !== null) {
                if (! hash_equals((string) $prior->supporter_identity_key, $identity) || $prior->process_type_code !== 'Impeachment') {
                    throw new ConflictHttpException('کلید تکرار درخواست برای عملیات دیگری استفاده شده است.');
                }
                $found = DB::table('digital_receipts')->where('support_idempotency_key', $idempotency)->first();
                $priorProcess = DB::table('processes')->where('process_id', $prior->process_id)->first();
                if ($found !== null && $priorProcess !== null
                    && (int) $priorProcess->target_geographic_level_code === $level
                    && (int) $priorProcess->target_geographic_id === $geoId) return $found;
                throw new ConflictHttpException('رسید درخواست قبلی هنوز در دسترس نیست.');
            }
            $this->lockGeography($level, $geoId);
            if ($this->activeOfficeProcess($level, $geoId) !== null) {
                throw new ConflictHttpException('برای این مسئول و حوزه، درخواست فعالی وجود دارد؛ می‌توانید از آن حمایت کنید.');
            }
            $gateKey = $this->supportGate->assertImpeachmentCanStart($level, $geoId);
            $process = $this->createProcess($profile, $level, $geoId, $this->officeTitle($level, $geoId));
            $this->supportGate->bindProcess((int) $process->process_id, $gateKey);
            $election = $this->createElectionProcess($profile, $level, $geoId, (int) $process->process_id);
            DB::table('impeachment_election_links')->insert([
                'impeachment_process_id' => $process->process_id,
                'election_process_id' => $election->process_id,
                'outcome_code' => null,
                'resolved_at' => null,
                'created_at' => now(),
            ]);
            return $this->commitSupport($process, $profile, $identity, $idempotency);
        }, 3);
        return response()->json(['data' => $this->receiptResponse($receipt)], 201);
    }

    public function support(Request $request, string $office, int $processId): JsonResponse
    {
        $level = $this->officeLevel($office);
        $data = $request->validate([
            'idempotency_key' => ['required', 'uuid'],
            'confirmation_method' => ['required', 'in:password'],
            'password' => ['required', 'string', 'max:255'],
        ]);
        $profile = $request->attributes->get('user_profile');
        $this->confirmAccount($profile, $data['password']);
        $identity = $this->identity((string) $profile->national_id_hash);
        $idempotency = hash('sha256', str_replace('-', '', $data['idempotency_key']), true);
        if ($this->limited('impeachment-support:'.$profile->user_id, 20)) return response()->json(['message' => 'تعداد درخواست‌ها زیاد است؛ کمی بعد دوباره تلاش کنید.'], 429);
        $receipt = DB::transaction(function () use ($profile, $level, $processId, $identity, $idempotency): object {
            $prior = DB::table('support_participations')->where('idempotency_key', $idempotency)->first();
            if ($prior !== null) {
                if ((int) $prior->process_id !== $processId || ! hash_equals((string) $prior->supporter_identity_key, $identity)) throw new ConflictHttpException('کلید تکرار درخواست برای عملیات دیگری استفاده شده است.');
                $found = DB::table('digital_receipts')->where('support_idempotency_key', $idempotency)->first();
                if ($found !== null) return $found;
            }
            $process = DB::table('processes as p')->join('process_states as ps', function ($join): void { $join->on('ps.process_id', '=', 'p.process_id')->whereNull('ps.current_state_completed_at'); })
                ->where('p.process_id', $processId)->where('p.process_type_code', 'Impeachment')->where('p.target_geographic_level_code', $level)
                ->lockForUpdate()->first(['p.*', 'ps.current_state_code']);
            if ($process === null || $process->current_state_code !== 'Supporting') throw new ConflictHttpException('این درخواست دیگر در مرحلهٔ دریافت حمایت نیست.');
            if (! $this->profileMatches($process, $profile)) throw new ConflictHttpException('حوزهٔ کاربری شما با این درخواست استیضاح مطابقت ندارد.');
            if (DB::table('support_participations')->where('process_id', $processId)->where('supporter_identity_key', $identity)->exists()) throw new ConflictHttpException('پیش‌تر از این درخواست حمایت کرده‌اید.');
            return $this->commitSupport($process, $profile, $identity, $idempotency);
        }, 3);
        return response()->json(['data' => $this->receiptResponse($receipt)], 201);
    }

    private function createProcess(object $profile, int $level, int $geoId, string $title): object
    {
        return $this->createScopedProcess($profile, $level, $geoId, 'Impeachment', $title, 'IMPEACHMENT-OFFICE-V1', 'IMPEACHMENT_CONFIDENCE_YES_NO', [
            ['YES', 'YES', 'موافق استیضاح و برکناری'],
            ['NO', 'NO', 'مخالف استیضاح و موافق ابقا'],
        ]);
    }

    private function createElectionProcess(object $profile, int $level, int $geoId, int $impeachmentProcessId): object
    {
        $geoName = match ($level) { 1 => DB::table('countries')->where('country_id', $geoId)->value('name_fa'), 2 => DB::table('provinces')->where('province_id', $geoId)->value('name_fa'), 3 => DB::table('counties')->where('county_id', $geoId)->value('name_fa'), 4 => DB::table('settlements')->where('settlement_id', $geoId)->value('name_fa') };
        $scope = match ($level) { 1 => 'کشور', 2 => 'استان', 3 => 'شهرستان', 4 => 'شهر یا روستا' };
        return $this->createScopedProcess($profile, $level, $geoId, 'Election', 'انتخابات جایگزینی '.$scope.' '.$geoName.' — فرآیند '.$impeachmentProcessId, 'IMPEACHMENT-TRIGGERED-ELECTION-V1', 'ELECTION_WRITE_IN_V1', []);
    }

    /** @param list<array{0:string,1:string,2:string}> $options */
    private function createScopedProcess(object $profile, int $level, int $geoId, string $type, string $title, string $normalizationVersion, string $ballotSchema, array $options): object
    {
        $policy = ProcessLifecyclePolicyVersion::query()->where('is_active', true)->where('effective_from', '<=', now())
            ->where(fn ($q) => $q->whereNull('effective_to')->orWhere('effective_to', '>', now()))->lockForUpdate()->first();
        if ($policy === null) throw new UnprocessableEntityHttpException('سیاست چرخهٔ فرایند تنظیم نشده است.');
        $column = match ($level) { 1 => 'country_id', 2 => 'province_id', 3 => 'county_id', 4 => 'settlement_id' };
        $population = (int) DB::table('user_profiles as up')->join('user_accounts as ua', 'ua.user_id', '=', 'up.user_id')
            ->where('up.is_active', true)->where('ua.account_status', 'Active')->where('up.'.$column, $geoId)->count();
        if ($population < 1) throw new UnprocessableEntityHttpException('در این حوزه کاربر فعالی ثبت نشده است.');
        $now = now();
        $shard = DB::table('shard_catalog')->where('shard_state_code', 'ONLINE')->where('connection_name', DB::getDefaultConnection())->orderByRaw("CASE WHEN shard_id = 'primary' THEN 0 ELSE 1 END")->first(['shard_id']);
        if ($shard === null) throw new UnprocessableEntityHttpException('هیچ شارد فعالی برای ایجاد فرایند در دسترس نیست.');
        $processId = DB::table('process_shard_placements')->insertGetId(['shard_id' => $shard->shard_id, 'placement_state_code' => 'CREATING', 'placement_version' => 1, 'assigned_at' => $now, 'activated_at' => null, 'updated_at' => $now], 'process_id');
        DB::table('processes')->insert([
            'process_id' => $processId, 'process_type_code' => $type,
            'process_lifecycle_policy_version_id' => $policy->process_lifecycle_policy_version_id,
            'target_geographic_level_code' => $level, 'target_geographic_id' => $geoId,
            'title' => $title, 'normalized_title' => $title, 'normalized_title_hash' => hash('sha256', mb_strtolower($title, 'UTF-8'), true),
            'normalization_version' => $normalizationVersion, 'created_by_user_id' => $profile->user_id,
            'voting_opens_at' => $now->copy()->addSeconds($policy->support_period_seconds + $policy->waiting_period_seconds),
            'voting_closes_at' => $now->copy()->addSeconds($policy->support_period_seconds + $policy->waiting_period_seconds + $policy->voting_period_seconds),
            'ballot_schema_id' => $ballotSchema, 'ballot_schema_version' => 1,
            'canonical_encoding_version' => 1, 'vote_token_ttl_seconds' => 300, 'result_publication_interval_seconds' => 600,
            'created_at' => $now, 'updated_at' => $now,
        ]);
        $stateId = DB::table('process_states')->insertGetId(['process_id' => $processId, 'current_state_code' => 'Supporting', 'current_state_started_at' => $now, 'current_state_completed_at' => null, 'created_at' => $now, 'updated_at' => $now]);
        $this->notifications->recordState($processId, (int) $stateId, 'Supporting', $now);
        DB::table('process_population_snapshots')->insert(['process_id' => $processId, 'frozen_population_total' => $population, 'captured_at' => $now]);
        if ($options !== []) DB::table('process_ballot_options')->insert(array_map(fn (array $option): array => [
            'process_id' => $processId, 'option_key' => $option[0], 'option_type_code' => $option[1],
            'display_label' => $option[2], 'is_active' => true, 'created_at' => $now,
        ], $options));
        DB::table('process_shard_placements')->where('process_id', $processId)->update(['placement_state_code' => 'ACTIVE', 'activated_at' => $now, 'updated_at' => $now]);
        DB::table('process_shard_placement_history')->insert([
            ['process_id' => $processId, 'placement_version' => 1, 'placement_event_no' => 1, 'source_shard_id' => null, 'destination_shard_id' => $shard->shard_id, 'operation_event_code' => 'PLACEMENT_PREPARED', 'created_at' => $now, 'completed_at' => $now],
            ['process_id' => $processId, 'placement_version' => 1, 'placement_event_no' => 2, 'source_shard_id' => null, 'destination_shard_id' => $shard->shard_id, 'operation_event_code' => 'CUTOVER', 'created_at' => $now, 'completed_at' => $now],
        ]);
        return DB::table('processes')->where('process_id', $processId)->first();
    }

    private function commitSupport(object $process, object $profile, string $identity, string $idempotency): object
    {
        $now = now();
        $supportId = DB::table('support_participations')->insertGetId([
            'process_id' => $process->process_id, 'process_type_code' => 'Impeachment', 'supporter_identity_key' => $identity,
            'idempotency_key' => $idempotency, 'participated_at' => $now, 'country_id' => $profile->country_id,
            'province_id' => $profile->province_id, 'county_id' => $profile->county_id, 'settlement_id' => $profile->settlement_id,
        ]);
        $number = random_bytes(32);
        $issuedAt = $now->copy()->utc()->format('Y-m-d H:i:s.v');
        $payload = ['domain' => 'vetoapp-support-receipt-v1', 'payload_version' => 1, 'receipt_type_code' => 'SUPPORT',
            'receipt_number' => bin2hex($number), 'process_id' => (string) $process->process_id, 'process_type_code' => 'Impeachment',
            'event_title' => $process->title, 'issued_at' => str_replace(' ', 'T', $issuedAt).'Z', 'key_id' => (string) config('services.process_receipts.key_id')];
        ksort($payload);
        $hash = hash('sha256', json_encode($payload, JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE), true);
        $signed = $this->receipts->sign($hash);
        $receiptId = DB::table('digital_receipts')->insertGetId([
            'process_id' => $process->process_id, 'beneficiary_user_account_id' => $profile->user_id, 'participant_identity_key' => $identity,
            'support_idempotency_key' => $idempotency, 'receipt_type_code' => 'SUPPORT', 'process_type_code' => 'Impeachment',
            'event_title_snapshot' => $process->title, 'receipt_number' => $number, 'payload_version' => 1, 'receipt_hash' => $hash,
            'signature_value' => $signed['signature'], 'key_id' => $signed['key_id'], 'issued_at' => $issuedAt,
        ]);
        DB::table('digital_receipt_support_details')->insert(['digital_receipt_id' => $receiptId, 'support_payload_version' => 1, 'support_note_snapshot' => null, 'created_at' => $now]);
        DB::table('process_projection_outbox_events')->insert([
            'process_id' => $process->process_id, 'event_type_code' => 'SUPPORT_COMMITTED', 'source_record_id' => $supportId,
            'event_key' => hash('sha256', 'SUPPORT_COMMITTED|'.bin2hex($idempotency), true),
            'payload' => json_encode(['process_id' => (string) $process->process_id, 'support_participation_id' => (string) $supportId,
                'geographic_level_code' => (int) $process->target_geographic_level_code, 'geographic_id' => (int) $process->target_geographic_id], JSON_THROW_ON_ERROR),
            'created_at' => $now, 'processed_at' => null, 'attempts' => 0,
        ]);
        return DB::table('digital_receipts')->where('digital_receipt_id', $receiptId)->first();
    }

    private function query(string $kind, int $level): \Illuminate\Database\Query\Builder
    {
        $counts = DB::table('support_participations')->select('process_id', DB::raw('COUNT(*) as support_count'))->groupBy('process_id');
        $query = DB::table('processes as p')->join('process_shard_placements as pl', fn ($j) => $j->on('pl.process_id', '=', 'p.process_id')->where('pl.placement_state_code', 'ACTIVE'))
            ->join('process_states as ps', fn ($j) => $j->on('ps.process_id', '=', 'p.process_id')->whereNull('ps.current_state_completed_at'))
            ->join('process_lifecycle_policy_versions as policy', 'policy.process_lifecycle_policy_version_id', '=', 'p.process_lifecycle_policy_version_id')
            ->join('process_population_snapshots as pop', 'pop.process_id', '=', 'p.process_id')->leftJoinSub($counts, 'sc', fn ($j) => $j->on('sc.process_id', '=', 'p.process_id'))
            ->leftJoin('countries as c', fn ($j) => $j->on('c.country_id', '=', 'p.target_geographic_id')->where('p.target_geographic_level_code', 1))
            ->leftJoin('provinces as pr', fn ($j) => $j->on('pr.province_id', '=', 'p.target_geographic_id')->where('p.target_geographic_level_code', 2))
            ->leftJoin('counties as co', fn ($j) => $j->on('co.county_id', '=', 'p.target_geographic_id')->where('p.target_geographic_level_code', 3))
            ->leftJoin('settlements as s', fn ($j) => $j->on('s.settlement_id', '=', 'p.target_geographic_id')->where('p.target_geographic_level_code', 4))
            ->where('p.process_type_code', 'Impeachment')->where('p.target_geographic_level_code', $level)
            ->select(['p.*', 'ps.current_state_code', 'ps.current_state_started_at', 'policy.threshold_rate_ppm', 'policy.min_support_count', 'policy.waiting_period_seconds', 'policy.voting_period_seconds', 'pop.frozen_population_total', DB::raw('COALESCE(sc.support_count,0) as support_count'), DB::raw("CASE p.target_geographic_level_code WHEN 1 THEN 'کشور' WHEN 2 THEN 'استان' WHEN 3 THEN 'شهرستان' ELSE 'شهر یا روستا' END as geographic_label"), DB::raw('COALESCE(c.name_fa,pr.name_fa,co.name_fa,s.name_fa) as geographic_name')]);
        return match ($kind) {
            'supporting' => $query->where('ps.current_state_code', 'Supporting'),
            'scheduled' => $query->where('ps.current_state_code', 'Waiting'),
            'eligible', 'live' => $query->where('ps.current_state_code', 'VoteCasting')->where('p.voting_closes_at', '>', now()),
            'finalized' => $query->whereIn('ps.current_state_code', ['Finalized', 'Failed'])->whereExists(fn ($q) => $q->selectRaw('1')->from('process_merkle_trees as mt')->whereColumn('mt.process_id', 'p.process_id')->where('mt.checkpoint_kind', 'FINAL')->whereNotNull('mt.published_at')),
            default => $query,
        };
    }

    private function summary(object $row): array
    {
        $required = max((int) $row->min_support_count, (int) ceil((int) $row->frozen_population_total * (int) $row->threshold_rate_ppm / 1_000_000));
        $opens = $row->current_state_code === 'Waiting' ? Carbon::parse($row->current_state_started_at)->addSeconds((int) $row->waiting_period_seconds) : null;
        return ['process_id' => (int) $row->process_id, 'title' => $row->title, 'state_code' => $row->current_state_code,
            'geographic_level_code' => (int) $row->target_geographic_level_code, 'geographic_id' => (int) $row->target_geographic_id,
            'geographic_label' => $row->geographic_label, 'geographic_name' => $row->geographic_name,
            'support_count' => (int) $row->support_count, 'required_support_count' => $required, 'frozen_population_total' => (int) $row->frozen_population_total,
            'expected_voting_opens_at' => $opens?->toISOString(), 'voting_opens_at' => $row->voting_opens_at, 'voting_closes_at' => $row->voting_closes_at];
    }

    private function officeTitle(int $level, int $geoId): string
    {
        $geoName = match ($level) { 1 => DB::table('countries')->where('country_id', $geoId)->value('name_fa'), 2 => DB::table('provinces')->where('province_id', $geoId)->value('name_fa'), 3 => DB::table('counties')->where('county_id', $geoId)->value('name_fa'), 4 => DB::table('settlements')->where('settlement_id', $geoId)->value('name_fa') };
        $scope = match ($level) { 1 => 'کشور', 2 => 'استان', 3 => 'شهرستان', 4 => 'شهر یا روستا' };
        return 'درخواست استیضاح در '.$scope.' '.$geoName;
    }

    private function activeOfficeProcess(int $level, int $geoId): ?object
    {
        return DB::table('processes as p')->join('process_states as ps', fn ($j) => $j->on('ps.process_id', '=', 'p.process_id')->whereNull('ps.current_state_completed_at'))
            ->where('p.process_type_code', 'Impeachment')->where('p.target_geographic_level_code', $level)->where('p.target_geographic_id', $geoId)
            ->whereIn('ps.current_state_code', ['Supporting', 'Waiting', 'VoteCasting', 'Publishing'])->lockForUpdate()->first(['p.process_id']);
    }

    private function lockGeography(int $level, int $id): void
    {
        [$table, $key] = match ($level) { 1 => ['countries','country_id'], 2 => ['provinces','province_id'], 3 => ['counties','county_id'], 4 => ['settlements','settlement_id'] };
        if (! DB::table($table)->where($key, $id)->lockForUpdate()->exists()) throw new UnprocessableEntityHttpException('دامنهٔ جغرافیایی معتبر نیست.');
    }

    private function profileGeoId(object $profile, int $level): int { return (int) match ($level) { 1 => $profile->country_id, 2 => $profile->province_id, 3 => $profile->county_id, 4 => $profile->settlement_id }; }
    private function profileMatches(object $process, object $profile): bool { return $this->profileGeoId($profile, (int) $process->target_geographic_level_code) === (int) $process->target_geographic_id; }
    private function officeLevel(string $office): int { return match ($office) { 'president' => 1, 'governor' => 2, 'county' => 3, 'local' => 4, default => abort(404) }; }
    private function confirmAccount(object $profile, string $password): void
    {
        $account = $profile->account()->first();
        if ($account === null || $account->account_status !== 'Active' || ($account->locked_until !== null && $account->locked_until->isFuture())) throw new UnprocessableEntityHttpException('حساب کاربری در وضعیت مجاز نیست.');
        if (! Hash::check($password, (string) $account->password_hash)) throw ValidationException::withMessages(['password' => ['رمز عبور صحیح نیست.']]);
    }
    private function filterEligible($query, object $profile): void
    {
        $geo = fn ($level) => $this->profileGeoId($profile, $level);
        $query->where(function ($q) use ($geo): void { foreach ([1,2,3,4] as $level) $q->orWhere(fn ($b) => $b->where('p.target_geographic_level_code', $level)->where('p.target_geographic_id', $geo($level))); });
        $identity = $this->identity((string) $profile->national_id_hash);
        $query->whereNotExists(fn ($q) => $q->selectRaw('1')->from('voter_participations as vp')->whereColumn('vp.process_id', 'p.process_id')->where('vp.participant_identity_key', $identity));
    }
    private function filterGeography($query, int $level, int $id): void
    {
        $query->where(function ($q) use ($level, $id): void {
            $q->where(fn ($e) => $e->where('p.target_geographic_level_code', $level)->where('p.target_geographic_id', $id));
            if ($level === 1) $q->orWhereExists(fn ($x) => $x->selectRaw('1')->from('provinces as g')->whereColumn('g.province_id','p.target_geographic_id')->where('p.target_geographic_level_code',2)->where('g.country_id',$id))
                ->orWhereExists(fn ($x) => $x->selectRaw('1')->from('counties as g')->join('provinces as p2','p2.province_id','=','g.province_id')->whereColumn('g.county_id','p.target_geographic_id')->where('p.target_geographic_level_code',3)->where('p2.country_id',$id))
                ->orWhereExists(fn ($x) => $x->selectRaw('1')->from('settlements as g')->join('counties as c','c.county_id','=','g.county_id')->join('provinces as p2','p2.province_id','=','c.province_id')->whereColumn('g.settlement_id','p.target_geographic_id')->where('p.target_geographic_level_code',4)->where('p2.country_id',$id));
            elseif ($level === 2) $q->orWhereExists(fn ($x) => $x->selectRaw('1')->from('counties as g')->whereColumn('g.county_id','p.target_geographic_id')->where('p.target_geographic_level_code',3)->where('g.province_id',$id))
                ->orWhereExists(fn ($x) => $x->selectRaw('1')->from('settlements as g')->join('counties as c','c.county_id','=','g.county_id')->whereColumn('g.settlement_id','p.target_geographic_id')->where('p.target_geographic_level_code',4)->where('c.province_id',$id));
            elseif ($level === 3) $q->orWhereExists(fn ($x) => $x->selectRaw('1')->from('settlements as g')->whereColumn('g.settlement_id','p.target_geographic_id')->where('p.target_geographic_level_code',4)->where('g.county_id',$id));
        });
    }
    private function identity(string $nationalIdHash): string
    {
        $key = (string) config('services.process_receipts.identity_hmac_key');
        if (strlen($key) < 32) throw new \RuntimeException('PROCESS_IDENTITY_HMAC_KEY must be configured with at least 32 characters.');
        return hash_hmac('sha256', 'support-v1|'.bin2hex($nationalIdHash), $key, true);
    }
    private function limited(string $key, int $max): bool { if (RateLimiter::tooManyAttempts($key, $max)) return true; RateLimiter::hit($key, 60); return false; }
    private function receiptResponse(object $receipt): array
    {
        return ['receipt_number' => rtrim(strtr(base64_encode((string) $receipt->receipt_number), '+/', '-_'), '='), 'receipt_hash' => rtrim(strtr(base64_encode((string) $receipt->receipt_hash), '+/', '-_'), '='),
            'signature' => rtrim(strtr(base64_encode((string) $receipt->signature_value), '+/', '-_'), '='), 'key_id' => $receipt->key_id, 'issued_at' => $receipt->issued_at, 'process_id' => (int) $receipt->process_id, 'title' => $receipt->event_title_snapshot];
    }
}
