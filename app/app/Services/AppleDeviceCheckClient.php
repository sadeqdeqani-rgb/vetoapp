<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Str;
use RuntimeException;

class AppleDeviceCheckClient
{
    public function isConfigured(): bool
    {
        return (string) config('services.apple_device_check.team_id') !== ''
            && (string) config('services.apple_device_check.key_id') !== ''
            && (string) config('services.apple_device_check.private_key') !== '';
    }

    /** @return array{bit0: bool, bit1: bool} */
    public function query(string $deviceToken): array
    {
        $response = $this->post('query_two_bits', $deviceToken);

        return [
            'bit0' => (bool) $response->json('bit0', false),
            'bit1' => (bool) $response->json('bit1', false),
        ];
    }

    public function markRequested(string $deviceToken): void
    {
        $this->post('update_two_bits', $deviceToken, ['bit0' => true]);
    }

    /** @param array<string, bool> $extra */
    private function post(string $operation, string $deviceToken, array $extra = []): \Illuminate\Http\Client\Response
    {
        $teamId = (string) config('services.apple_device_check.team_id');
        $keyId = (string) config('services.apple_device_check.key_id');
        $privateKey = str_replace('\\n', "\n", (string) config('services.apple_device_check.private_key'));
        if ($teamId === '' || $keyId === '' || $privateKey === '') {
            throw new RuntimeException('Apple DeviceCheck credentials are not configured.');
        }

        $payload = [
            'device_token' => $deviceToken,
            'transaction_id' => (string) Str::uuid(),
            'timestamp' => (int) floor(microtime(true) * 1000),
            ...$extra,
        ];
        $base = config('services.apple_device_check.environment') === 'development'
            ? 'https://api.development.devicecheck.apple.com'
            : 'https://api.devicecheck.apple.com';
        $response = Http::acceptJson()->withToken($this->jwt($teamId, $keyId, $privateKey))
            ->timeout(8)->post($base.'/v1/'.$operation, $payload);
        if (! $response->successful()) {
            throw new RuntimeException('Apple DeviceCheck request failed with HTTP '.$response->status().'.');
        }

        return $response;
    }

    private function jwt(string $teamId, string $keyId, string $privateKey): string
    {
        $encode = static fn (string $value): string => rtrim(strtr(base64_encode($value), '+/', '-_'), '=');
        $header = $encode(json_encode(['alg' => 'ES256', 'kid' => $keyId, 'typ' => 'JWT'], JSON_THROW_ON_ERROR));
        $claims = $encode(json_encode(['iss' => $teamId, 'iat' => time()], JSON_THROW_ON_ERROR));
        $input = $header.'.'.$claims;
        $key = openssl_pkey_get_private($privateKey);
        if ($key === false || ! openssl_sign($input, $der, $key, OPENSSL_ALGO_SHA256)) {
            throw new RuntimeException('Apple DeviceCheck signing key could not sign a request.');
        }

        return $input.'.'.$encode($this->derEcdsaToRaw($der));
    }

    private function derEcdsaToRaw(string $der): string
    {
        $offset = 2;
        if (ord($der[1]) & 0x80) {
            $offset = 2 + (ord($der[1]) & 0x7f);
        }
        if (ord($der[$offset]) !== 0x02) {
            throw new RuntimeException('Invalid ECDSA signature returned by OpenSSL.');
        }
        $rLength = ord($der[$offset + 1]);
        $r = substr($der, $offset + 2, $rLength);
        $offset += 2 + $rLength;
        if (ord($der[$offset]) !== 0x02) {
            throw new RuntimeException('Invalid ECDSA signature returned by OpenSSL.');
        }
        $sLength = ord($der[$offset + 1]);
        $s = substr($der, $offset + 2, $sLength);
        $r = str_pad(substr($r, -32), 32, "\0", STR_PAD_LEFT);
        $s = str_pad(substr($s, -32), 32, "\0", STR_PAD_LEFT);

        return $r.$s;
    }
}
