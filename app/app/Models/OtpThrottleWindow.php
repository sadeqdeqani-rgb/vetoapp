<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class OtpThrottleWindow extends Model
{
    protected $table = 'otp_throttle_windows';
    protected $primaryKey = 'otp_throttle_window_id';
    protected $guarded = [];

    protected function casts(): array
    {
        return [
            'window_started_at' => 'datetime',
            'window_ends_at' => 'datetime',
            'last_sent_at' => 'datetime',
            'throttled_until' => 'datetime',
            'blocked_until' => 'datetime',
            'send_count' => 'integer',
            'verify_failed_count' => 'integer',
            'penalty_tier' => 'integer',
        ];
    }
}
