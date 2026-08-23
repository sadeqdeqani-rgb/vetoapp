<?php

namespace App\Services;

use App\Models\SystemAdmin;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class AdminAuditService
{
    public function record(
        Request $request,
        SystemAdmin $admin,
        string $action,
        string $targetTable,
        string|int|null $targetId = null,
        ?array $before = null,
        ?array $after = null,
    ): void {
        DB::table('admin_activity_logs')->insert([
            'admin_id' => $admin->admin_id,
            'action_name' => $action,
            'target_table' => $targetTable,
            'target_id' => $targetId === null ? null : (string) $targetId,
            'payload_before' => $before === null ? null : json_encode($before, JSON_UNESCAPED_UNICODE),
            'payload_after' => $after === null ? null : json_encode($after, JSON_UNESCAPED_UNICODE),
            'digital_signature' => null,
            'client_ip' => (string) $request->ip(),
            'user_agent' => $request->userAgent(),
            'created_at' => now(),
        ]);
    }
}
