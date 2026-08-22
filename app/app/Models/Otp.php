<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Otp extends Model
{
    protected $table = 'otps';
    protected $primaryKey = 'otp_id';

    protected $guarded = [];

    protected function casts(): array
    {
        return [
            'issued_at' => 'datetime',
            'expires_at' => 'datetime',
            'verified_at' => 'datetime',
            'failed_at' => 'datetime',
            'attempt_count' => 'integer',
            'max_attempt_count' => 'integer',
            'registration_draft_id' => 'integer',
            'user_id' => 'integer',
            'otp_throttle_window_id' => 'integer',
        ];
    }
}
