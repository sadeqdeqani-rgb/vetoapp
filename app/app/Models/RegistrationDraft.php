<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class RegistrationDraft extends Model
{
    protected $table = 'registration_drafts';
    protected $primaryKey = 'registration_draft_id';
    public $incrementing = true;

    protected $fillable = [
        'state_code',
        'step_code',
        'idempotency_key',
        'mobile_hash',
        'mobile_encrypted',
        'national_id_hash',
        'national_id_encrypted',
        'key_version',
        'settlement_id',
        'telegram_link_nonce_hash',
        'telegram_link_nonce_expires_at',
        'telegram_link_nonce_used_at',
        'mobile_verified_at',
        'expires_at',
        'completed_at',
    ];

    protected function casts(): array
    {
        return [
            'key_version' => 'integer',
            'settlement_id' => 'integer',
            'telegram_link_nonce_expires_at' => 'datetime',
            'telegram_link_nonce_used_at' => 'datetime',
            'mobile_verified_at' => 'datetime',
            'expires_at' => 'datetime',
            'completed_at' => 'datetime',
        ];
    }

    public function telegramIdentities(): HasMany
    {
        return $this->hasMany(UserTelegramIdentity::class, 'registration_draft_id', 'registration_draft_id');
    }

    public function settlement(): BelongsTo
    {
        return $this->belongsTo(Settlement::class, 'settlement_id', 'settlement_id');
    }
}
