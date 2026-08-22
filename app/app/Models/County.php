<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class County extends Model
{
    protected $table = 'counties';
    protected $primaryKey = 'county_id';

    protected $fillable = [
        'province_id',
        'county_code',
        'name_fa',
        'is_active',
    ];

    protected function casts(): array
    {
        return [
            'province_id' => 'integer',
            'county_code' => 'integer',
            'is_active' => 'boolean',
        ];
    }

    public function province(): BelongsTo
    {
        return $this->belongsTo(Province::class, 'province_id', 'province_id');
    }

    public function settlements(): HasMany
    {
        return $this->hasMany(Settlement::class, 'county_id', 'county_id');
    }

    public function activeSettlements(): HasMany
    {
        return $this->settlements()->active();
    }

    public function scopeActive(Builder $query): Builder
    {
        return $query->where($query->qualifyColumn('is_active'), true);
    }
}
