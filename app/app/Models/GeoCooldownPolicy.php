<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class GeoCooldownPolicy extends Model
{
    protected $table = 'geo_cooldown_policies';
    protected $primaryKey = 'policy_id';

    protected $fillable = [
        'policy_code',
        'policy_name',
        'description',
        'policy_stage',
        'max_changes_allowed',
        'window_days',
        'cooldown_days',
        'is_active',
        'effective_from',
        'effective_to',
    ];

    protected function casts(): array
    {
        return [
            'policy_stage' => 'integer',
            'max_changes_allowed' => 'integer',
            'window_days' => 'integer',
            'cooldown_days' => 'integer',
            'is_active' => 'boolean',
            'effective_from' => 'datetime',
            'effective_to' => 'datetime',
        ];
    }
}
