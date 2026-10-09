<?php

namespace App\Services;

use Illuminate\Support\Facades\DB;
use RuntimeException;

class ProcessTreeHeadSigner
{
    /** @return array{key_id:string,signature:string,public_key:string,algorithm:string} */
    public function sign(string $canonicalTreeHead): array
    {
        if (! extension_loaded('sodium')) throw new RuntimeException('The sodium extension is required for tree-head signing.');
        $keyId = (string) config('services.process_tree_heads.key_id');
        $secret = base64_decode((string) config('services.process_tree_heads.private_key'), true);
        $public = base64_decode((string) config('services.process_tree_heads.public_key'), true);
        if (! preg_match('/^[A-Za-z0-9._-]{1,100}$/', $keyId)
            || $secret === false || strlen($secret) !== SODIUM_CRYPTO_SIGN_SECRETKEYBYTES
            || $public === false || strlen($public) !== SODIUM_CRYPTO_SIGN_PUBLICKEYBYTES
            || ! hash_equals(sodium_crypto_sign_publickey_from_secretkey($secret), $public)) {
            throw new RuntimeException('Process tree-head signing key is missing or invalid.');
        }
        $signature = sodium_crypto_sign_detached(hash('sha256', $canonicalTreeHead, true), $secret);
        DB::table('process_receipt_signing_public_keys')->insertOrIgnore([
            'key_id' => $keyId, 'algorithm' => 'Ed25519', 'public_key' => $public, 'created_at' => now(),
        ]);
        $stored = DB::table('process_receipt_signing_public_keys')->where('key_id', $keyId)->value('public_key');
        if (! is_string($stored) || ! hash_equals($stored, $public)) throw new RuntimeException('Tree-head key id is bound to another public key.');
        return ['key_id' => $keyId, 'signature' => $signature, 'public_key' => $public, 'algorithm' => 'Ed25519'];
    }
}
