<?php

namespace App\Console\Commands;

use App\Services\TelegramBotClient;
use App\Services\TelegramUpdateIngestor;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Cache;
use Throwable;

class PollTelegramUpdatesCommand extends Command
{
    protected $signature = 'telegram:poll';

    protected $description = 'Receive Telegram updates with long polling.';

    public function handle(TelegramBotClient $telegram, TelegramUpdateIngestor $ingestor): int
    {
        if ((string) config('services.telegram.bot_token') === '') {
            $this->error('TELEGRAM_BOT_TOKEN is not configured.');

            return self::FAILURE;
        }

        $lock = Cache::lock('telegram:long-poll:single-instance', 180);
        while (!$lock->get()) {
            $this->warn('Another Telegram poller is already running; waiting for its lock.');
            sleep(5);
        }

        try {
            // Transition from webhook mode without discarding updates awaiting delivery.
            $telegram->deleteWebhook(dropPendingUpdates: false);
            $this->info('Telegram long polling started.');

            while (true) {
                if (!$lock->refresh(180)) {
                    logger()->critical('Telegram poller lost its single-instance lock.');
                    $this->error('Telegram poller lost its single-instance lock.');

                    return self::FAILURE;
                }

                try {
                    $offset = Cache::get('telegram:long-poll:offset');
                    $offset = $offset === null ? null : (int) $offset;
                    $updates = $telegram->getUpdates($offset, 50);

                    foreach ($updates as $update) {
                        if (!$lock->refresh(180)) {
                            logger()->critical('Telegram poller lost its single-instance lock.');
                            $this->error('Telegram poller lost its single-instance lock.');

                            return self::FAILURE;
                        }

                        if (!is_array($update) || !isset($update['update_id'])) {
                            continue;
                        }

                        $ingestor->ingest($update);
                        Cache::forever('telegram:long-poll:offset', (int) $update['update_id'] + 1);
                    }
                } catch (Throwable $exception) {
                    // HTTP exceptions can include the bot token in their URL; never report them verbatim.
                    logger()->warning('Telegram polling request failed.', [
                        'exception' => class_basename($exception),
                    ]);
                    $this->warn('Telegram polling request failed; retrying shortly.');
                    sleep(5);
                }
            }
        } catch (Throwable $exception) {
            logger()->error('Telegram long polling could not start.', [
                'exception' => class_basename($exception),
            ]);
            $this->error('Telegram long polling could not start.');

            return self::FAILURE;
        } finally {
            $lock->release();
        }
    }
}
