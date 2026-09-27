<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class NationalIdAgeEligibilityReport extends Model
{
    protected $table = 'national_id_age_eligibility_reports';
    protected $primaryKey = 'report_id';

    protected $fillable = [
        'registration_draft_id',
        'national_id_hash',
        'national_id_encrypted',
        'birth_date_encrypted',
        'status_code',
        'admin_note',
    ];
}
