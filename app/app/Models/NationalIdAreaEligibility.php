<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class NationalIdAreaEligibility extends Model
{
    protected $table = 'national_id_area_eligibilities';
    protected $primaryKey = 'national_id_prefix_3';
    public $incrementing = false;

    protected $fillable = [
        'national_id_prefix_3',
        'first_range_from',
        'first_range_to',
        'second_range_from',
        'second_range_to',
    ];
}
