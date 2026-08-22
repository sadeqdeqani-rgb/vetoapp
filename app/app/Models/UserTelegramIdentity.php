<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class UserTelegramIdentity extends Model
{
    protected $table = 'user_telegram_identities';
    protected $primaryKey = 'telegram_identity_id';

    protected $fillable = [
        'user_id',
        'registration_draft_id',
        'telegram_user_id',
        'chat_id',
        'username',
        'link_status',
        'verified_mobile_hash',
        'phone_verified_at',
        'phone_verification_status',
        'linked_at',
        'last_seen_at',
    ];

    protected function casts(): array
    {
        return [
            'telegram_user_id' => 'integer',
            'chat_id' => 'integer',
            'phone_verified_at' => 'datetime',
            'linked_at' => 'datetime',
            'last_seen_at' => 'datetime',
        ];
    }

    public function draft(): BelongsTo
    {
        return $this->belongsTo(RegistrationDraft::class, 'registration_draft_id', 'registration_draft_id');
    }

    public function profile(): BelongsTo
    {
        return $this->belongsTo(UserProfile::class, 'user_id', 'user_id');
    }
}
