<?php

namespace App\Http\Controllers;

use App\Models\UserProfile;
use Illuminate\Http\JsonResponse;

class DashboardController extends Controller
{
    public function summary(): JsonResponse
    {
        return response()->json([
            'data' => [
                'active_user_count' => UserProfile::query()
                    ->where('is_active', true)
                    ->count(),
                // Referendum, election, and impeachment records are not yet
                // represented in the backend data model.
                'live_activity_data_available' => false,
            ],
        ]);
    }
}
