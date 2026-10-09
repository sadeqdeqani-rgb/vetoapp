<?php

namespace App\Services;

use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use RuntimeException;

class ProcessMerkleInclusionProof
{
    public function forReceipt(object $receipt): array
    {
        if ($receipt->receipt_type_code !== 'VOTE') {
            return ['status' => 'not_applicable'];
        }

        $vote = DB::table('digital_receipt_vote_details as detail')
            ->join('ballot_box_entries as ballot', 'ballot.ballot_box_entry_id', '=', 'detail.ballot_box_entry_id')
            ->where('detail.digital_receipt_id', $receipt->digital_receipt_id)
            ->first([
                'ballot.process_id', 'ballot.sequence_no', 'ballot.current_hash',
                'detail.ballot_commitment',
            ]);
        if ($vote === null || (int) $vote->process_id !== (int) $receipt->process_id
            || ! hash_equals((string) $vote->current_hash, (string) $vote->ballot_commitment)) {
            throw new RuntimeException('Vote receipt does not match its immutable ballot entry.');
        }

        $checkpoint = DB::table('process_merkle_trees')
            ->where('process_id', $receipt->process_id)
            ->whereIn('checkpoint_kind', ['FINAL', 'CORRECTION'])
            ->whereNotNull('published_at')
            ->where('leaf_count', '>=', $vote->sequence_no)
            ->orderByDesc('checkpoint_no')
            ->first();
        if ($checkpoint === null) {
            return [
                'status' => 'awaiting_final_checkpoint',
                'process_id' => (string) $receipt->process_id,
                'sequence_no' => (int) $vote->sequence_no,
            ];
        }

        $cacheKey = 'process-merkle-inclusion-v1:'.(int) $receipt->process_id.':'
            .(int) $vote->sequence_no.':'.(int) $checkpoint->merkle_tree_id;

        return Cache::remember($cacheKey, now()->addDays(30), function () use ($receipt, $vote, $checkpoint): array {
            return $this->buildProof($receipt, $vote, $checkpoint);
        });
    }

    private function buildProof(object $receipt, object $vote, object $checkpoint): array
    {
        $sequence = (int) $vote->sequence_no;
        $leafCount = (int) $checkpoint->leaf_count;
        if ($leafCount < 1 || (int) $checkpoint->last_sequence_no !== $leafCount || $sequence < 1 || $sequence > $leafCount) {
            throw new RuntimeException('Published checkpoint has an invalid leaf range.');
        }

        $leafHash = hash('sha256', "\x00".(string) $vote->current_hash, true);
        $proofNodes = $this->proofForRange((int) $receipt->process_id, 1, $leafCount, $sequence - 1);
        $computedRoot = $leafHash;
        foreach ($proofNodes as $node) {
            $sibling = $this->decodeBase64Url($node['hash']);
            if ($sibling === null || strlen($sibling) !== 32) throw new RuntimeException('Merkle proof node is malformed.');
            $computedRoot = $node['side'] === 'LEFT'
                ? hash('sha256', "\x01".$sibling.$computedRoot, true)
                : hash('sha256', "\x01".$computedRoot.$sibling, true);
        }
        if (! hash_equals((string) $checkpoint->root_hash, $computedRoot)) {
            throw new RuntimeException('Computed vote inclusion proof does not match the published root.');
        }

        $chainHead = DB::table('process_chain_heads')->where('process_id', $receipt->process_id)->first();
        if ($chainHead === null || (int) $chainHead->last_sequence_no !== $leafCount) {
            throw new RuntimeException('Final checkpoint does not match a frozen process chain head.');
        }

        $treeHead = [
            'domain' => 'vetoapp-signed-tree-head-v1',
            'process_id' => (string) $receipt->process_id,
            'checkpoint_no' => (int) $checkpoint->checkpoint_no,
            'checkpoint_kind' => $checkpoint->checkpoint_kind,
            'root_hash' => $this->base64Url((string) $checkpoint->root_hash),
            'tree_version' => $checkpoint->tree_version,
            'chain_hash_version' => $chainHead->hash_version,
            'canonical_encoding_version' => (int) $checkpoint->canonical_encoding_version,
            'leaf_count' => $leafCount,
            'last_sequence_no' => (int) $checkpoint->last_sequence_no,
            'last_chain_hash' => $this->base64Url((string) $chainHead->last_hash),
            'source_outbox_watermark' => (int) $checkpoint->source_outbox_watermark,
            'generated_at' => Carbon::parse($checkpoint->generated_at, 'UTC')->format('Y-m-d\\TH:i:s.u\\Z'),
            'signing_key_id' => $checkpoint->signing_key_id,
            'previous_checkpoint_id' => $checkpoint->previous_checkpoint_id === null
                ? null : (int) $checkpoint->previous_checkpoint_id,
        ];
        ksort($treeHead);
        $signedPayload = json_encode($treeHead, JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
        $publicKey = DB::table('process_receipt_signing_public_keys')
            ->where('key_id', $checkpoint->signing_key_id)->value('public_key');
        $checkpointSignatureValid = false;
        if (extension_loaded('sodium') && is_string($publicKey)) {
            try {
                $checkpointSignatureValid = sodium_crypto_sign_verify_detached(
                    (string) $checkpoint->signature_value,
                    hash('sha256', $signedPayload, true),
                    $publicKey,
                );
            } catch (\SodiumException | \TypeError) {
                $checkpointSignatureValid = false;
            }
        }

        return [
            'status' => $checkpointSignatureValid ? 'available' : 'invalid_checkpoint_signature',
            'process_id' => (string) $receipt->process_id,
            'sequence_no' => $sequence,
            'leaf_index' => $sequence - 1,
            'leaf_count' => $leafCount,
            'leaf_hash' => $this->base64Url($leafHash),
            'proof_nodes' => $proofNodes,
            'root_hash' => $this->base64Url($computedRoot),
            'tree_version' => $checkpoint->tree_version,
            'proof_algorithm' => 'RFC9162-MERKLE-TREE-HASH-SHA256',
            'leaf_encoding' => 'SHA-256(0x00 || BallotBoxEntry.current_hash)',
            'checkpoint' => [
                'signed_tree_head' => $treeHead,
                'signed_payload' => $signedPayload,
                'signature' => $this->base64Url((string) $checkpoint->signature_value),
                'signing_public_key' => is_string($publicKey) ? $this->base64Url($publicKey) : null,
                'signature_algorithm' => 'Ed25519',
                'signature_valid' => (bool) $checkpointSignatureValid,
                'published_at' => $checkpoint->published_at,
            ],
        ];
    }

    /** @return list<array{side:string,hash:string}> */
    private function proofForRange(int $processId, int $firstSequence, int $count, int $targetIndex): array
    {
        if ($count < 1 || $targetIndex < 0 || $targetIndex >= $count) {
            throw new RuntimeException('Merkle proof target is outside the checkpoint range.');
        }
        if ($count === 1) return [];

        $split = $this->largestPowerOfTwoLessThan($count);
        if ($targetIndex < $split) {
            $path = $this->proofForRange($processId, $firstSequence, $split, $targetIndex);
            $sibling = $this->rangeRoot($processId, $firstSequence + $split, $count - $split);
            $path[] = ['side' => 'RIGHT', 'hash' => $this->base64Url($sibling)];
            return $path;
        }

        $path = $this->proofForRange($processId, $firstSequence + $split, $count - $split, $targetIndex - $split);
        $sibling = $this->rangeRoot($processId, $firstSequence, $split);
        $path[] = ['side' => 'LEFT', 'hash' => $this->base64Url($sibling)];
        return $path;
    }

    private function rangeRoot(int $processId, int $firstSequence, int $count): string
    {
        $lastSequence = $firstSequence + $count - 1;
        $stack = [];
        $seen = 0;
        foreach (DB::table('ballot_box_entries')->where('process_id', $processId)
            ->whereBetween('sequence_no', [$firstSequence, $lastSequence])
            ->orderBy('sequence_no')->cursor() as $row) {
            $expected = $firstSequence + $seen;
            if ((int) $row->sequence_no !== $expected) throw new RuntimeException('Ballot sequence gap found while building Merkle proof.');
            $node = hash('sha256', "\x00".(string) $row->current_hash, true);
            $level = 0;
            while (array_key_exists($level, $stack)) {
                $node = hash('sha256', "\x01".$stack[$level].$node, true);
                unset($stack[$level]);
                $level++;
            }
            $stack[$level] = $node;
            $seen++;
        }
        if ($seen !== $count) throw new RuntimeException('Ballot sequence count does not match the requested Merkle range.');

        ksort($stack);
        $root = null;
        foreach ($stack as $subtreeRoot) {
            $root = $root === null ? $subtreeRoot : hash('sha256', "\x01".$subtreeRoot.$root, true);
        }
        if (! is_string($root)) throw new RuntimeException('Could not calculate a Merkle subtree root.');
        return $root;
    }

    private function largestPowerOfTwoLessThan(int $value): int
    {
        $power = 1;
        while (($power << 1) < $value) $power <<= 1;
        return $power;
    }

    private function base64Url(string $value): string
    {
        return rtrim(strtr(base64_encode($value), '+/', '-_'), '=');
    }

    private function decodeBase64Url(string $value): ?string
    {
        $decoded = base64_decode(strtr($value, '-_', '+/').str_repeat('=', (4 - strlen($value) % 4) % 4), true);
        return $decoded === false ? null : $decoded;
    }
}
