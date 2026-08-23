<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class AdminApiToken extends Model
{
    protected $table = 'admin_api_tokens';
    protected $primaryKey = 'token_id';
    public $timestamps = false;

    protected $fillable = [
        'admin_id',
        'token_hash',
        'expires_at',
        'last_used_at',
        'revoked_at',
        'created_at',
    ];

    protected function casts(): array
    {
        return [
            'expires_at' => 'datetime',
            'last_used_at' => 'datetime',
            'revoked_at' => 'datetime',
            'created_at' => 'datetime',
        ];
    }

    public function admin(): BelongsTo
    {
        return $this->belongsTo(SystemAdmin::class, 'admin_id', 'admin_id');
    }
}
