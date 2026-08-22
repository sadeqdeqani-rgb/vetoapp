<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class OtpDeliveryAttempt extends Model
{
    protected $table = 'otp_delivery_attempts';
    protected $primaryKey = 'delivery_attempt_id';
    public $timestamps = false;
    protected $guarded = [];
}
