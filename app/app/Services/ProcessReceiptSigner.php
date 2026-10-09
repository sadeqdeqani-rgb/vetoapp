<?php

namespace App\Services;

use Illuminate\Support\Facades\DB;
use RuntimeException;

class ProcessReceiptSigner
{
    /** @return array{key_id:string, signature:string, public_key:string, algorithm:string} */
    public function sign(string $receiptHash): array
    {
        if (! extension_loaded('sodium')) {
            throw new RuntimeException('The sodium extension is required for process receipt signing.');
        }

        $keyId = (string) config('services.process_receipts.key_id');
        $secret = base64_decode((string) config('services.process_receipts.private_key'), true);
        $public = base64_decode((string) config('services.process_receipts.public_key'), true);
        if (! preg_match('/^[A-Za-z0-9._-]{1,100}$/', $keyId)
            || $secret === false || strlen($secret) !== SODIUM_CRYPTO_SIGN_SECRETKEYBYTES
            || $public === false || strlen($public) !== SODIUM_CRYPTO_SIGN_PUBLICKEYBYTES
            || ! hash_equals(sodium_crypto_sign_publickey_from_secretkey($secret), $public)) {
            throw new RuntimeException('Process receipt signing key is missing or invalid.');
        }

        $signature = sodium_crypto_sign_detached($receiptHash, $secret);
        DB::table('process_receipt_signing_public_keys')->insertOrIgnore([
            'key_id' => $keyId,
            'algorithm' => 'Ed25519',
            'public_key' => $public,
            'created_at' => now(),
        ]);
        $storedPublicKey = DB::table('process_receipt_signing_public_keys')->where('key_id', $keyId)->value('public_key');
        if (! is_string($storedPublicKey) || ! hash_equals($storedPublicKey, $public)) {
            throw new RuntimeException('Receipt key id is already bound to a different public key.');
        }

        return [
            'key_id' => $keyId,
            'signature' => $signature,
            'public_key' => $public,
            'algorithm' => 'Ed25519',
        ];
    }

    public function publicKeys(): array
    {
        return DB::table('process_receipt_signing_public_keys')
            ->orderBy('created_at')
            ->get(['key_id', 'algorithm', 'public_key', 'created_at', 'retired_at'])
            ->map(fn ($key): array => [
                'key_id' => $key->key_id,
                'algorithm' => $key->algorithm,
                'public_key' => $this->base64UrlEncode((string) $key->public_key),
                'created_at' => $key->created_at,
                'retired_at' => $key->retired_at,
            ])->all();
    }

    private function base64UrlEncode(string $value): string
    {
        return rtrim(strtr(base64_encode($value), '+/', '-_'), '=');
    }
}
