<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Country extends Model
{
    protected $table = 'countries';
    protected $primaryKey = 'country_id';

    protected $fillable = [
        'country_code',
        'name_fa',
        'is_active',
    ];

    protected function casts(): array
    {
        return [
            'country_code' => 'integer',
            'is_active' => 'boolean',
        ];
    }

    public function provinces(): HasMany
    {
        return $this->hasMany(Province::class, 'country_id', 'country_id');
    }

    public function activeProvinces(): HasMany
    {
        return $this->provinces()->active();
    }

    public function scopeActive(Builder $query): Builder
    {
        return $query->where($query->qualifyColumn('is_active'), true);
    }
}
