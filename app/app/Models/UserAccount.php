<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class UserAccount extends Model
{
    protected $table = 'user_accounts';
    protected $primaryKey = 'user_id';
    public $incrementing = false;

    protected $fillable = [
        'user_id',
        'password_hash',
        'account_status',
        'mfa_required',
        'failed_login_count',
        'lockout_count',
        'password_changed_at',
        'password_reset_completed_at',
    ];

    protected function casts(): array
    {
        return [
            'user_id' => 'integer',
            'mfa_required' => 'boolean',
            'failed_login_count' => 'integer',
            'lockout_count' => 'integer',
            'password_changed_at' => 'datetime',
            'password_reset_completed_at' => 'datetime',
        ];
    }

    public function profile(): BelongsTo
    {
        return $this->belongsTo(UserProfile::class, 'user_id', 'user_id');
    }
}
