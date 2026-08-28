<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\QueryException;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        // Normalize values written by the first API implementation before adding
        // the lifecycle invariants from the database contract.
        DB::table('auth_sessions')
            ->where('terminal_reason', 'New_Login')
            ->update(['terminal_reason' => 'force_revocation']);

        DB::table('auth_sessions')
            ->where('terminal_reason', 'Logout')
            ->update([
                'state' => 'LoggedOut',
                'terminal_reason' => 'manual_logout',
            ]);

        if (DB::getDriverName() !== 'mysql') {
            return;
        }

        DB::statement("
            ALTER TABLE auth_sessions
            ADD CONSTRAINT chk_auth_session_authentication_method
                CHECK (authentication_method IN ('Password', 'Biometric')),
            ADD CONSTRAINT chk_auth_session_expiry_timeline
                CHECK (expires_at > issued_at),
            ADD CONSTRAINT chk_auth_session_last_activity_timeline
                CHECK (last_activity_at >= issued_at AND last_activity_at <= expires_at),
            ADD CONSTRAINT chk_auth_session_terminal_reason
                CHECK (
                    terminal_reason IS NULL
                    OR terminal_reason IN (
                        'inactivity_timeout',
                        'force_revocation',
                        'manual_logout',
                        'expired'
                    )
                ),
            ADD CONSTRAINT chk_auth_session_terminal_state
                CHECK (
                    (state = 'Active'
                        AND terminal_reason IS NULL
                        AND terminated_at IS NULL
                        AND revoked_at IS NULL
                        AND logged_out_at IS NULL)
                    OR (state = 'Expired'
                        AND terminal_reason IN ('expired', 'inactivity_timeout')
                        AND terminated_at IS NOT NULL
                        AND revoked_at IS NULL
                        AND logged_out_at IS NULL)
                    OR (state = 'Revoked'
                        AND terminal_reason = 'force_revocation'
                        AND terminated_at IS NOT NULL
                        AND revoked_at IS NOT NULL
                        AND logged_out_at IS NULL
                        AND revoked_at = terminated_at)
                    OR (state = 'LoggedOut'
                        AND terminal_reason = 'manual_logout'
                        AND terminated_at IS NOT NULL
                        AND revoked_at IS NULL
                        AND logged_out_at IS NOT NULL
                        AND logged_out_at = terminated_at)
                ),
            ADD CONSTRAINT chk_auth_session_terminated_timeline
                CHECK (
                    terminated_at IS NULL
                    OR (
                        terminated_at >= issued_at
                        AND terminated_at <= expires_at
                        AND terminated_at >= last_activity_at
                    )
                )
        ");
    }

    public function down(): void
    {
        if (DB::getDriverName() !== 'mysql') {
            return;
        }

        foreach ([
            'chk_auth_session_authentication_method',
            'chk_auth_session_expiry_timeline',
            'chk_auth_session_last_activity_timeline',
            'chk_auth_session_terminal_reason',
            'chk_auth_session_terminal_state',
            'chk_auth_session_terminated_timeline',
        ] as $constraint) {
            try {
                DB::statement("ALTER TABLE auth_sessions DROP CHECK {$constraint}");
            } catch (QueryException) {
                // Keep rollback idempotent across MySQL 8 minor versions.
            }
        }
    }
};
