<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use App\Services\ProcessTreeHeadSigner;
use App\Services\ProcessNotificationRecorder;
use App\Services\ProcessSupportGateService;

class AdvanceReferendumLifecycleCommand extends Command
{
    protected $signature = 'referendum:advance-lifecycle {--batch=500}';

    protected $description = 'Project process events and advance referendum, election, and impeachment states.';

    public function __construct(
        private readonly ProcessTreeHeadSigner $treeHeadSigner,
        private readonly ProcessNotificationRecorder $notifications,
        private readonly ProcessSupportGateService $supportGate,
    )
    {
        parent::__construct();
    }

    public function handle(): int
    {
        $batch = max(1, min(5000, (int) $this->option('batch')));
        $processed = 0;
        $ids = DB::table('process_projection_outbox_events')
            ->where('event_type_code', 'SUPPORT_COMMITTED')
            ->whereNull('processed_at')
            ->orderBy('process_projection_outbox_event_id')
            ->limit($batch)
            ->pluck('process_projection_outbox_event_id');

        foreach ($ids as $id) {
            try {
                DB::transaction(function () use ($id, &$processed): void {
                $event = DB::table('process_projection_outbox_events')
                    ->where('process_projection_outbox_event_id', $id)
                    ->lockForUpdate()->first();
                if ($event === null || $event->processed_at !== null) return;

                $payload = json_decode((string) $event->payload, true, flags: JSON_THROW_ON_ERROR);
                $level = (int) ($payload['geographic_level_code'] ?? 0);
                $geoId = (int) ($payload['geographic_id'] ?? 0);
                if ($level < 1 || $level > 4 || $geoId < 1) {
                    throw new \UnexpectedValueException('Support projection event has invalid geography.');
                }

                DB::table('process_geographic_counters')->insertOrIgnore([
                    'process_id' => $event->process_id,
                    'counter_type' => 'SUPPORT',
                    'geographic_level_code' => $level,
                    'geographic_id' => $geoId,
                    'ballot_choice_key' => 'ALL',
                    'counter_value' => 0,
                    'last_reconciled_at' => null,
                ]);
                DB::table('process_geographic_counters')
                    ->where('process_id', $event->process_id)
                    ->where('counter_type', 'SUPPORT')
                    ->where('geographic_level_code', $level)
                    ->where('geographic_id', $geoId)
                    ->where('ballot_choice_key', 'ALL')
                    ->increment('counter_value');

                DB::table('process_projection_outbox_events')
                    ->where('process_projection_outbox_event_id', $id)
                    ->update(['processed_at' => now(), 'attempts' => DB::raw('attempts + 1')]);
                $processed++;

                $process = $this->processForUpdate((int) $event->process_id);
                if ($process !== null && $process->current_state_code === 'Supporting') {
                    $count = (int) DB::table('process_geographic_counters')
                        ->where('process_id', $process->process_id)
                        ->where('counter_type', 'SUPPORT')
                        ->where('geographic_level_code', $process->target_geographic_level_code)
                        ->where('geographic_id', $process->target_geographic_id)
                        ->where('ballot_choice_key', 'ALL')->value('counter_value');
                    if ($count >= $this->requiredSupport($process)) {
                        $this->transition($process, 'Waiting');
                    }
                }
                }, 3);
            } catch (\Throwable $exception) {
                DB::table('process_projection_outbox_events')
                    ->where('process_projection_outbox_event_id', $id)
                    ->whereNull('processed_at')
                    ->increment('attempts');
                Log::error('Referendum support projection failed; it will be retried.', [
                    'outbox_event_id' => (int) $id,
                    'exception' => $exception::class,
                ]);
            }
        }

        $this->projectVotingEvents($batch);
        $this->advanceTimedStates($batch);
        $this->line("Processed support events: {$processed}");

        return self::SUCCESS;
    }

    private function advanceTimedStates(int $batch): void
    {
        $ids = DB::table('process_states as ps')
            ->join('processes as p', 'p.process_id', '=', 'ps.process_id')
            ->whereIn('p.process_type_code', ['Referendum', 'Election', 'Impeachment'])
            ->whereNull('ps.current_state_completed_at')
            ->whereIn('ps.current_state_code', ['Supporting', 'Waiting', 'VoteCasting', 'Publishing'])
            ->orderBy('ps.process_id')->limit($batch)
            ->pluck('ps.process_id');

        foreach ($ids as $id) {
            DB::transaction(function () use ($id): void {
                $process = $this->processForUpdate((int) $id);
                if ($process === null) return;
                $now = now();
                $started = Carbon::parse($process->current_state_started_at);

                if ($process->current_state_code === 'Supporting') {
                    if ($process->process_type_code === 'Election'
                        && DB::table('impeachment_election_links')->where('election_process_id', $id)->whereNull('resolved_at')->exists()) return;
                    $deadline = $started->copy()->addSeconds((int) $process->support_period_seconds);
                    if ($now->lt($deadline)) return;
                    $pending = DB::table('process_projection_outbox_events')
                        ->where('process_id', $id)->where('event_type_code', 'SUPPORT_COMMITTED')
                        ->whereNull('processed_at')->exists();
                    if ($pending) return;
                    $count = (int) DB::table('process_geographic_counters')
                        ->where('process_id', $id)->where('counter_type', 'SUPPORT')
                        ->where('geographic_level_code', $process->target_geographic_level_code)
                        ->where('geographic_id', $process->target_geographic_id)
                        ->where('ballot_choice_key', 'ALL')->value('counter_value');
                    $this->transition($process, $count >= $this->requiredSupport($process) ? 'Waiting' : 'Failed');
                    return;
                }

                if ($process->current_state_code === 'Waiting'
                    && $now->gte($started->copy()->addSeconds((int) $process->waiting_period_seconds))) {
                    // Set the immutable voting window before inserting VoteCasting.
                    DB::table('processes')->where('process_id', $id)->update([
                        'voting_opens_at' => $now,
                        'voting_closes_at' => $now->copy()->addSeconds((int) $process->voting_period_seconds),
                        'updated_at' => $now,
                    ]);
                    $this->transition($process, 'VoteCasting');
                    return;
                }

                if ($process->current_state_code === 'VoteCasting'
                    && $now->gte(Carbon::parse($process->voting_closes_at))) {
                    $ballotCount = (int) DB::table('ballot_box_entries')->where('process_id', $id)->count();
                    if ($ballotCount === 0) {
                        $this->transition($process, 'Failed', 'EMPTY_VOTING_PERIOD');
                        return;
                    }
                    $this->freezeChainHead((int) $id, $now);
                    $this->transition($process, 'Publishing');
                    return;
                }

                if ($process->current_state_code === 'Publishing'
                    && $now->gte($started->copy()->addSeconds((int) $process->publication_delay_seconds))) {
                    $hasFinalCheckpoint = DB::table('process_merkle_trees')
                        ->where('process_id', $id)->where('checkpoint_kind', 'FINAL')
                        ->whereNotNull('published_at')->exists();
                    if (! $hasFinalCheckpoint) {
                        if (DB::table('process_projection_outbox_events')->where('process_id', $id)->whereNull('processed_at')->exists()) return;
                        $this->publishFinalCheckpoint((int) $id);
                        $hasFinalCheckpoint = true;
                    }
                    if ($hasFinalCheckpoint) {
                        if ($process->process_type_code === 'Impeachment') {
                            $votes = DB::table('ballot_box_entries')->where('process_id', $id)
                                ->select('ballot_option_key', DB::raw('COUNT(*) AS vote_count'))
                                ->groupBy('ballot_option_key')->pluck('vote_count', 'ballot_option_key');
                            $removed = (int) ($votes['YES'] ?? 0) > (int) ($votes['NO'] ?? 0);
                            if (! $removed) {
                                // A tie means retention; every other non-removal result also cancels this replacement election.
                                $this->transition($process, 'Failed', 'IMPEACHMENT_RETAINED_AFTER_VOTE');
                            } else {
                                $this->transition($process, 'Finalized');
                                $this->advanceLinkedElectionAfterRemoval($process);
                            }
                        } else {
                            $this->transition($process, 'Finalized');
                        }
                    }
                }
            }, 3);
        }
    }

    private function projectVotingEvents(int $batch): void
    {
        $ids = DB::table('process_projection_outbox_events')
            ->where('event_type_code', 'VOTE_COMMITTED')->whereNull('processed_at')
            ->orderBy('process_projection_outbox_event_id')->limit($batch)
            ->pluck('process_projection_outbox_event_id');

        foreach ($ids as $id) {
            try {
                DB::transaction(function () use ($id): void {
                    $event = DB::table('process_projection_outbox_events')
                        ->where('process_projection_outbox_event_id', $id)->lockForUpdate()->first();
                    if ($event === null || $event->processed_at !== null) return;
                    $ballot = DB::table('ballot_box_entries')->where('ballot_box_entry_id', $event->source_record_id)->first();
                    $process = DB::table('processes')->where('process_id', $event->process_id)->first(['target_geographic_level_code']);
                    if ($ballot === null || $process === null || (int) $ballot->process_id !== (int) $event->process_id) {
                        throw new \UnexpectedValueException('Vote projection source does not match its outbox event.');
                    }
                    $geographies = [
                        1 => (int) $ballot->country_id,
                        2 => (int) $ballot->province_id,
                        3 => (int) $ballot->county_id,
                        4 => (int) $ballot->settlement_id,
                    ];
                    foreach ($geographies as $level => $geoId) {
                        if ($level < (int) $process->target_geographic_level_code) continue;
                        foreach ([(string) $ballot->ballot_option_key, 'ALL'] as $choice) {
                            DB::table('process_geographic_counters')->insertOrIgnore([
                                'process_id' => $event->process_id,
                                'counter_type' => 'VOTE',
                                'geographic_level_code' => $level,
                                'geographic_id' => $geoId,
                                'ballot_choice_key' => $choice,
                                'counter_value' => 0,
                            ]);
                            DB::table('process_geographic_counters')->where('process_id', $event->process_id)
                                ->where('counter_type', 'VOTE')->where('geographic_level_code', $level)
                                ->where('geographic_id', $geoId)->where('ballot_choice_key', $choice)->increment('counter_value');
                        }
                    }
                    DB::table('process_projection_outbox_events')->where('process_projection_outbox_event_id', $id)
                        ->update(['processed_at' => now(), 'attempts' => DB::raw('attempts + 1')]);
                }, 3);
            } catch (\Throwable $exception) {
                DB::table('process_projection_outbox_events')->where('process_projection_outbox_event_id', $id)
                    ->whereNull('processed_at')->increment('attempts');
                Log::error('Vote result projection failed; it will be retried.', [
                    'outbox_event_id' => (int) $id,
                    'exception' => $exception::class,
                ]);
            }
        }
    }

    private function freezeChainHead(int $processId, Carbon $closedAt): void
    {
        $allocator = DB::table('process_sequence_allocators')->where('process_id', $processId)->lockForUpdate()->first();
        if ($allocator === null || $allocator->hash_version !== 'SHA-256-TLV1-DOMAIN02') {
            throw new \RuntimeException('Cannot freeze a missing or unsupported process sequence allocator.');
        }
        $lastSequence = (int) $allocator->next_sequence_no - 1;
        if ($lastSequence < 1) throw new \RuntimeException('An empty ballot chain must not be finalized.');
        $lastEntryHash = DB::table('ballot_box_entries')->where('process_id', $processId)
            ->where('sequence_no', $lastSequence)->value('current_hash');
        if (! is_string($lastEntryHash) || ! hash_equals($lastEntryHash, (string) $allocator->last_hash)) {
            throw new \RuntimeException('Sequence allocator tail does not match the ballot ledger.');
        }
        $existing = DB::table('process_chain_heads')->where('process_id', $processId)->first();
        if ($existing !== null) {
            if ((int) $existing->last_sequence_no !== $lastSequence || ! hash_equals((string) $existing->last_hash, (string) $allocator->last_hash)
                || $existing->hash_version !== $allocator->hash_version) {
                throw new \RuntimeException('An existing immutable chain head conflicts with the allocator.');
            }
            return;
        }
        DB::table('process_chain_heads')->insert([
            'process_id' => $processId,
            'last_sequence_no' => $lastSequence,
            'last_hash' => $allocator->last_hash,
            'hash_version' => $allocator->hash_version,
            'finalized_at' => $closedAt,
        ]);
    }

    private function publishFinalCheckpoint(int $processId): void
    {
        $sequence = DB::table('process_sequence_allocators')->where('process_id', $processId)->lockForUpdate()->first();
        $headRow = DB::table('process_chain_heads')->where('process_id', $processId)->first();
        if ($sequence === null || $headRow === null) throw new \RuntimeException('Final checkpoint requires a frozen chain head.');
        $lastSequence = (int) $headRow->last_sequence_no;
        $lastHash = (string) $headRow->last_hash;
        if ($lastSequence !== (int) $sequence->next_sequence_no - 1
            || ! hash_equals($lastHash, (string) $sequence->last_hash)
            || $headRow->hash_version !== $sequence->hash_version) {
            throw new \RuntimeException('Frozen chain head does not match the sequence allocator.');
        }
        $rows = DB::table('ballot_box_entries')->where('process_id', $processId)->orderBy('sequence_no')->get(['sequence_no', 'current_hash']);
        if ($rows->count() !== $lastSequence) {
            throw new \RuntimeException('Ballot chain sequence does not match the sequence allocator.');
        }

        $leaves = $rows->map(fn (object $row): string => hash('sha256', "\x00".(string) $row->current_hash, true))->all();
        $root = $this->merkleRoot($leaves);
        $now = now()->utc();
        $prior = DB::table('process_merkle_trees')->where('process_id', $processId)->orderByDesc('checkpoint_no')->first();
        $checkpointNo = (int) (DB::table('process_merkle_trees')->where('process_id', $processId)->max('checkpoint_no') ?? 0) + 1;
        $watermark = (int) (DB::table('process_projection_outbox_events')->where('process_id', $processId)->max('process_projection_outbox_event_id') ?? 0);
        $signingKeyId = (string) config('services.process_tree_heads.key_id');
        $head = [
            'domain' => 'vetoapp-signed-tree-head-v1',
            'process_id' => (string) $processId,
            'checkpoint_no' => $checkpointNo,
            'checkpoint_kind' => 'FINAL',
            'root_hash' => rtrim(strtr(base64_encode($root), '+/', '-_'), '='),
            'tree_version' => 'RFC9162-SHA256-CHAINHASH-V1',
            'chain_hash_version' => (string) $headRow->hash_version,
            'canonical_encoding_version' => 1,
            'leaf_count' => $lastSequence,
            'last_sequence_no' => $lastSequence,
            'last_chain_hash' => rtrim(strtr(base64_encode($lastHash), '+/', '-_'), '='),
            'source_outbox_watermark' => $watermark,
            'generated_at' => $now->format('Y-m-d\TH:i:s.u\Z'),
            'signing_key_id' => $signingKeyId,
            'previous_checkpoint_id' => $prior?->merkle_tree_id === null ? null : (int) $prior->merkle_tree_id,
        ];
        ksort($head);
        $signature = $this->treeHeadSigner->sign($this->canonicalJson($head));

        DB::table('process_merkle_trees')->insert([
            'process_id' => $processId,
            'checkpoint_no' => $checkpointNo,
            'previous_checkpoint_id' => $prior?->merkle_tree_id,
            'supersedes_checkpoint_id' => null,
            'correction_reason' => null,
            'checkpoint_kind' => 'FINAL',
            'root_hash' => $root,
            'tree_version' => 'RFC9162-SHA256-CHAINHASH-V1',
            'canonical_encoding_version' => 1,
            'leaf_count' => $lastSequence,
            'last_sequence_no' => $lastSequence,
            'source_outbox_watermark' => $watermark,
            'signature_value' => $signature['signature'],
            'signing_key_id' => $signature['key_id'],
            'generated_at' => $now,
            'published_at' => $now,
        ]);

    }

    /** @param list<string> $leaves */
    private function merkleRoot(array $leaves): string
    {
        if ($leaves === []) return hash('sha256', '', true);
        if (count($leaves) === 1) return $leaves[0];
        $split = 1;
        while (($split << 1) < count($leaves)) $split <<= 1;
        $left = $this->merkleRoot(array_slice($leaves, 0, $split));
        $right = $this->merkleRoot(array_slice($leaves, $split));
        return hash('sha256', "\x01".$left.$right, true);
    }

    private function canonicalJson(array $value): string { ksort($value); return json_encode($value, JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE); }

    private function processForUpdate(int $processId): ?object
    {
        return DB::table('processes as p')
            ->join('process_states as ps', function ($join): void {
                $join->on('ps.process_id', '=', 'p.process_id')->whereNull('ps.current_state_completed_at');
            })
            ->join('process_lifecycle_policy_versions as policy', 'policy.process_lifecycle_policy_version_id', '=', 'p.process_lifecycle_policy_version_id')
            ->join('process_population_snapshots as pop', 'pop.process_id', '=', 'p.process_id')
            ->where('p.process_id', $processId)->whereIn('p.process_type_code', ['Referendum', 'Election', 'Impeachment'])
            ->lockForUpdate()
            ->first([
                'p.process_id', 'p.process_type_code', 'p.target_geographic_level_code', 'p.target_geographic_id',
                'p.title', 'p.normalized_title', 'p.normalized_title_hash', 'p.voting_closes_at',
                'ps.current_state_code', 'ps.current_state_started_at',
                'pop.frozen_population_total', 'policy.threshold_rate_ppm', 'policy.min_support_count',
                'policy.support_period_seconds', 'policy.waiting_period_seconds',
                'policy.voting_period_seconds', 'policy.publication_delay_seconds',
            ]);
    }

    private function requiredSupport(object $process): int
    {
        return max(
            (int) $process->min_support_count,
            (int) ceil((int) $process->frozen_population_total * (int) $process->threshold_rate_ppm / 1_000_000),
        );
    }

    private function transition(object $process, string $toState, ?string $explicitEvent = null): void
    {
        $fromState = (string) $process->current_state_code;
        $eventCode = $explicitEvent ?? match ([$fromState, $toState]) {
            ['Supporting', 'Waiting'] => 'SUPPORT_THRESHOLD_MET',
            ['Supporting', 'Failed'] => 'SUPPORT_PERIOD_EXPIRED',
            ['Waiting', 'VoteCasting'] => 'WAITING_PERIOD_ELAPSED',
            ['VoteCasting', 'Publishing'] => 'VOTING_PERIOD_ELAPSED',
            ['VoteCasting', 'Failed'] => 'EMPTY_VOTING_PERIOD',
            ['Publishing', 'Finalized'] => 'PUBLICATION_DELAY_ELAPSED',
            default => throw new \LogicException("Unsupported referendum transition: {$fromState} -> {$toState}"),
        };
        $ruleExists = DB::table('process_transition_rules')
            ->where('process_type_code', (string) $process->process_type_code)
            ->where('from_state_code', $fromState)
            ->where('to_state_code', $toState)
            ->where('event_code', $eventCode)
            ->where('is_active', true)
            ->where('effective_from', '<=', now())
            ->where(fn ($query) => $query->whereNull('effective_to')->orWhere('effective_to', '>', now()))
            ->exists();
        if (! $ruleExists) {
            throw new \LogicException("No active transition rule for {$fromState} -> {$toState}.");
        }

        $now = now();
        DB::table('process_states')->where('process_id', $process->process_id)
            ->whereNull('current_state_completed_at')->update([
                'current_state_completed_at' => $now,
                'updated_at' => $now,
            ]);
        $stateId = DB::table('process_states')->insertGetId([
            'process_id' => $process->process_id,
            'current_state_code' => $toState,
            'current_state_started_at' => $now,
            'current_state_completed_at' => null,
            'created_at' => $now,
            'updated_at' => $now,
        ]);
        $this->notifications->recordState((int) $process->process_id, (int) $stateId, $toState, $now);

        if ($fromState === 'Supporting' && in_array($toState, ['Waiting', 'Failed'], true)
            && in_array((string) $process->process_type_code, ['Referendum', 'Impeachment'], true)) {
            $this->supportGate->recordSupportResolution(
                $process,
                $toState === 'Waiting',
                $now,
            );
        }

        if ($process->process_type_code === 'Impeachment' && $toState === 'Failed') {
            $this->failLinkedElection($process, $eventCode === 'IMPEACHMENT_RETAINED_AFTER_VOTE' ? 'RETAINED' : 'CANCELLED');
        }
    }

    private function advanceLinkedElectionAfterRemoval(object $impeachment): void
    {
        $link = DB::table('impeachment_election_links')->where('impeachment_process_id', $impeachment->process_id)->lockForUpdate()->first();
        if ($link === null || $link->resolved_at !== null) return;
        $election = $this->processForUpdate((int) $link->election_process_id);
        if ($election === null || $election->process_type_code !== 'Election' || $election->current_state_code !== 'Supporting') {
            throw new \LogicException('The linked replacement election is not in its expected Supporting state.');
        }
        $this->transition($election, 'Waiting', 'IMPEACHMENT_REMOVAL_FINALIZED');
        DB::table('impeachment_election_links')->where('impeachment_process_id', $impeachment->process_id)->whereNull('resolved_at')
            ->update(['outcome_code' => 'REMOVED', 'resolved_at' => now()]);
    }

    private function failLinkedElection(object $impeachment, string $outcome): void
    {
        $link = DB::table('impeachment_election_links')->where('impeachment_process_id', $impeachment->process_id)->lockForUpdate()->first();
        if ($link === null || $link->resolved_at !== null) return;
        $election = $this->processForUpdate((int) $link->election_process_id);
        if ($election !== null && $election->process_type_code === 'Election' && $election->current_state_code === 'Supporting') {
            $this->transition($election, 'Failed', 'IMPEACHMENT_RETENTION_FINALIZED');
        }
        DB::table('impeachment_election_links')->where('impeachment_process_id', $impeachment->process_id)->whereNull('resolved_at')
            ->update(['outcome_code' => $outcome, 'resolved_at' => now()]);
    }
}
