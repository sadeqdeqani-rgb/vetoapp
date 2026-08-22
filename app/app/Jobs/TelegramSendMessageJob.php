<?php

namespace App\Jobs;

use App\Models\OtpDeliveryAttempt;
use App\Models\UserTelegramIdentity;
use App\Services\TelegramBotClient;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Crypt;
use Throwable;

class TelegramSendMessageJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public int $tries = 3;
    public int $backoff = 10;

    public function __construct(
        public int $deliveryAttemptId,
        public string $encryptedCode,
    ) {
    }

    public function handle(TelegramBotClient $telegram): void
    {
        $attempt = OtpDeliveryAttempt::query()->findOrFail($this->deliveryAttemptId);
        $identity = UserTelegramIdentity::query()
            ->whereKey($attempt->telegram_identity_id)
            ->where('phone_verification_status', 'Verified')
            ->firstOrFail();

        $result = $telegram->sendMessage(
            (int) $identity->chat_id,
            'کد تأیید وتواپ: '.Crypt::decryptString($this->encryptedCode).' (اعتبار: ۲ دقیقه)'
        );

        $attempt->forceFill([
            'status' => 'Sent',
            'provider_message_id' => isset($result['message_id']) ? (string) $result['message_id'] : null,
            'delivered_at' => now(),
        ])->save();
    }

    public function failed(Throwable $exception): void
    {
        OtpDeliveryAttempt::query()
            ->whereKey($this->deliveryAttemptId)
            ->update([
                'status' => 'Failed',
                'failure_code' => substr($exception::class, 0, 64),
            ]);
    }
}
