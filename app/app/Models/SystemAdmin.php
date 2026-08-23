<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class SystemAdmin extends Model
{
    protected $table = 'system_admins';
    protected $primaryKey = 'admin_id';
    public $incrementing = true;
    protected $keyType = 'int';

    protected $fillable = [
        'admin_uuid',
        'username',
        'password_hash',
        'public_key_pem',
        'is_active',
    ];

    protected $hidden = [
        'password_hash',
        'public_key_pem',
    ];

    protected function casts(): array
    {
        return [
            'is_active' => 'boolean',
        ];
    }

    public function apiTokens(): HasMany
    {
        return $this->hasMany(AdminApiToken::class, 'admin_id', 'admin_id');
    }
}
