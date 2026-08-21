<?php

use App\Http\Controllers\NationalCodeController;
use Illuminate\Support\Facades\Route;

Route::post('/registration/validate-national-code', [
    NationalCodeController::class,
    'validateNationalCode',
]);
