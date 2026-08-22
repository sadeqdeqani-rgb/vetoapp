<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Settlement extends Model
{
    protected $table = 'settlements';
    protected $primaryKey = 'settlement_id';

    protected $fillable = [
        'county_id',
        'settlement_code',
        'name_fa',
        'is_active',
    ];

    protected function casts(): array
    {
        return [
            'county_id' => 'integer',
            'settlement_code' => 'integer',
            'is_active' => 'boolean',
        ];
    }

    public function county(): BelongsTo
    {
        return $this->belongsTo(County::class, 'county_id', 'county_id');
    }

    public function scopeActive(Builder $query): Builder
    {
        return $query->where($query->qualifyColumn('is_active'), true);
    }

    public function scopeForCounty(Builder $query, int $countyId): Builder
    {
        return $query->where($query->qualifyColumn('county_id'), $countyId);
    }

    public function scopeWithinHierarchy(
        Builder $query,
        int $countryId,
        int $provinceId,
        int $countyId
    ): Builder {
        return $query
            ->where($query->qualifyColumn('county_id'), $countyId)
            ->whereHas('county', function (Builder $countyQuery) use ($provinceId, $countryId): void {
                $countyQuery
                    ->where('province_id', $provinceId)
                    ->whereHas('province', fn (Builder $provinceQuery) => $provinceQuery->where('country_id', $countryId));
            });
    }
}
