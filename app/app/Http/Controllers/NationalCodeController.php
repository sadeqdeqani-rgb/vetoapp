<?php

namespace App\Http\Controllers;

use App\Support\IranianNationalCodeValidator;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class NationalCodeController extends Controller
{
    public function validateNationalCode(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'national_code' => ['required', 'string'],
        ]);

        // TODO: پس از پایان تست، این مقدار باید false یا configurable شود.
        $allowTestCode = true;
        $isValid = IranianNationalCodeValidator::isValid(
            $validated['national_code'],
            $allowTestCode,
        );

        return response()->json([
            'valid' => $isValid,
            'national_code' => IranianNationalCodeValidator::normalize(
                $validated['national_code'],
            ),
        ], $isValid ? 200 : 422);
    }
}
