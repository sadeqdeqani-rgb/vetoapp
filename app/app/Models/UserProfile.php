<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasOne;

class UserProfile extends Model
{
    protected $table = 'user_profiles';
    protected $primaryKey = 'user_id';
    public $incrementing = true;
    public $timestamps = false;

    protected $fillable = [
        'mobile_hash',
        'mobile_encrypted',
        'national_id_hash',
        'national_id_encrypted',
        'settlement_id',
        'county_id',
        'province_id',
        'country_id',
        'is_active',
        'created_at',
        'geo_updated_at',
        'initial_geo_selected_at',
    ];

    protected function casts(): array
    {
        return [
            'settlement_id' => 'integer',
            'county_id' => 'integer',
            'province_id' => 'integer',
            'country_id' => 'integer',
            'is_active' => 'boolean',
            'created_at' => 'datetime',
            'geo_updated_at' => 'datetime',
            'initial_geo_selected_at' => 'datetime',
        ];
    }

    public function account(): HasOne
    {
        return $this->hasOne(UserAccount::class, 'user_id', 'user_id');
    }
}
