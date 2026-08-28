<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class AccountClosurePenaltyPolicy extends Model
{
    protected $table = 'account_closure_penalty_policies';
    protected $primaryKey = 'policy_id';

    protected $fillable = [
        'policy_family_code',
        'policy_code',
        'policy_name',
        'description',
        'penalty_stage',
        'penalty_hours',
        'trigger_scope',
        'is_active',
        'effective_from',
        'effective_to',
    ];

    protected function casts(): array
    {
        return [
            'penalty_stage' => 'integer',
            'penalty_hours' => 'integer',
            'is_active' => 'boolean',
            'effective_from' => 'datetime',
            'effective_to' => 'datetime',
        ];
    }
}
