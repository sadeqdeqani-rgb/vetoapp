<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class IntegrationInboxEntry extends Model
{
    protected $table = 'integration_inbox_entries';
    protected $primaryKey = 'inbox_entry_id';
    protected $guarded = [];

    protected function casts(): array
    {
        return [
            'payload' => 'array',
            'received_at' => 'datetime',
            'processed_at' => 'datetime',
        ];
    }
}
