<?php

namespace App\Http\Controllers;

use App\Services\AppleDeviceCheckClient;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\RateLimiter;
use RuntimeException;
use Symfony\Component\HttpKernel\Exception\ServiceUnavailableHttpException;

class ActivationRequestController extends Controller
{
    private const REQUIRED_REQUESTS = 45000000;

    public function count(): JsonResponse
    {
        $count = (int) DB::table('activation_request_counters')->sum('request_count');

        return response()->json(['data' => [
            'required_count' => self::REQUIRED_REQUESTS,
            'request_count' => $count,
            'remaining_count' => max(0, self::REQUIRED_REQUESTS - $count),
        ]])->header('Cache-Control', 'no-store');
    }

    public function store(Request $request, AppleDeviceCheckClient $apple): JsonResponse
    {
        $data = $request->validate([
            'platform' => ['required', 'in:android,ios'],
            'device_identifier' => ['required', 'string', 'min:16', 'max:256'],
            'device_check_token' => ['required_if:platform,ios', 'nullable', 'string', 'min:32', 'max:8192'],
        ]);
        $hmacKey = (string) config('services.activation_requests.hmac_key');
        if (strlen($hmacKey) < 32) {
            throw new ServiceUnavailableHttpException(null, 'سرویس ثبت درخواست هنوز پیکربندی نشده است.');
        }
        $deviceKeyHash = hash_hmac('sha256', $data['platform'].':'.$data['device_identifier'], $hmacKey);
        $rateKey = 'activation-request:'.hash('sha256', (string) $request->ip());
        if (RateLimiter::tooManyAttempts($rateKey, 20)) {
            return response()->json(['message' => 'تعداد درخواست‌ها زیاد است. کمی بعد دوباره تلاش کنید.'], 429);
        }
        RateLimiter::hit($rateKey, 3600);

        if ($data['platform'] === 'ios') {
            return $this->storeIos($data, $deviceKeyHash, $apple);
        }

        return $this->storeAndroid($deviceKeyHash);
    }

    private function storeAndroid(string $deviceKeyHash): JsonResponse
    {
        $inserted = DB::transaction(function () use ($deviceKeyHash): bool {
            $created = DB::table('activation_client_requests')->insertOrIgnore([
                'platform_code' => 'android',
                'device_key_hash' => $deviceKeyHash,
                'requested_at' => now(),
            ]) === 1;
            if ($created) {
                $this->incrementCounter($deviceKeyHash);
            }

            return $created;
        }, attempts: 3);

        return $this->result($inserted);
    }

    /** @param array<string, string> $data */
    private function storeIos(array $data, string $deviceKeyHash, AppleDeviceCheckClient $apple): JsonResponse
    {
        if (DB::table('activation_client_requests')->where('device_key_hash', $deviceKeyHash)->exists()) {
            return $this->result(false);
        }
        if (! $apple->isConfigured()) {
            // Keychain-backed identifier remains the fallback until Apple server credentials are provisioned.
            $inserted = DB::transaction(function () use ($deviceKeyHash): bool {
                $created = DB::table('activation_client_requests')->insertOrIgnore([
                    'platform_code' => 'ios',
                    'device_key_hash' => $deviceKeyHash,
                    'requested_at' => now(),
                ]) === 1;
                if ($created) {
                    $this->incrementCounter($deviceKeyHash);
                }

                return $created;
            }, attempts: 3);

            return $this->result($inserted);
        }

        try {
            $bits = $apple->query((string) $data['device_check_token']);
            if ($bits['bit0']) {
                return $this->result(false);
            }
            DB::transaction(function () use ($data, $deviceKeyHash, $apple): void {
                $inserted = DB::table('activation_client_requests')->insertOrIgnore([
                    'platform_code' => 'ios',
                    'device_key_hash' => $deviceKeyHash,
                    'requested_at' => now(),
                ]);
                if ($inserted !== 1) {
                    throw new DuplicateActivationRequest();
                }
                $this->incrementCounter($deviceKeyHash);
                // DeviceCheck bit 0 is reserved for this app's one-request rule.
                $apple->markRequested((string) $data['device_check_token']);
            }, attempts: 1);
        } catch (DuplicateActivationRequest) {
            return $this->result(false);
        } catch (RuntimeException $exception) {
            report($exception);
            throw new ServiceUnavailableHttpException(null, 'تأیید دستگاه انجام نشد. اتصال اینترنت را بررسی و دوباره تلاش کنید.');
        }

        return $this->result(true);
    }

    private function result(bool $created): JsonResponse
    {
        $count = (int) DB::table('activation_request_counters')->sum('request_count');

        return response()->json(['data' => [
            'created' => $created,
            'message' => $created
                ? 'درخواست شما برای شروع به کار سامانه ثبت شد.'
                : 'شما قبلاً درخواست خود برای شروع به کار سامانه را ثبت کرده‌اید.',
            'required_count' => self::REQUIRED_REQUESTS,
            'request_count' => $count,
            'remaining_count' => max(0, self::REQUIRED_REQUESTS - $count),
        ], 'message' => $created
            ? 'درخواست شما برای شروع به کار سامانه ثبت شد.'
            : 'شما قبلاً درخواست خود برای شروع به کار سامانه را ثبت کرده‌اید.']);
    }

    private function incrementCounter(string $deviceKeyHash): void
    {
        $bucket = hexdec(substr($deviceKeyHash, 0, 2)) % 64;
        DB::table('activation_request_counters')
            ->where('counter_bucket', $bucket)
            ->increment('request_count', 1, ['updated_at' => now()]);
    }
}

class DuplicateActivationRequest extends \RuntimeException {}
