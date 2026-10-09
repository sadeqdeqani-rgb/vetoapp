<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class ProcessLifecyclePolicyVersion extends Model
{
    protected $table = 'process_lifecycle_policy_versions';
    protected $primaryKey = 'process_lifecycle_policy_version_id';
    public $timestamps = false;

    protected $fillable = [
        'version_number',
        'support_threshold_policy_code',
        'threshold_rate_ppm',
        'rounding_mode_code',
        'min_support_count',
        'support_period_seconds',
        'waiting_period_seconds',
        'voting_period_seconds',
        'publication_delay_seconds',
        'is_active',
        'effective_from',
        'effective_to',
        'created_by_admin_id',
        'created_at',
    ];

    protected function casts(): array
    {
        return [
            'threshold_rate_ppm' => 'integer',
            'min_support_count' => 'integer',
            'support_period_seconds' => 'integer',
            'waiting_period_seconds' => 'integer',
            'voting_period_seconds' => 'integer',
            'publication_delay_seconds' => 'integer',
            'is_active' => 'boolean',
            'effective_from' => 'datetime',
            'effective_to' => 'datetime',
            'created_at' => 'datetime',
        ];
    }
}
