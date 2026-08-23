<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;

class SystemTermsContent extends Model
{
    protected $table = 'system_terms_contents';
    protected $primaryKey = 'terms_content_id';

    protected $fillable = [
        'version_number',
        'title',
        'body_text',
        'is_active',
        'published_at',
    ];

    protected function casts(): array
    {
        return [
            'version_number' => 'integer',
            'is_active' => 'boolean',
            'published_at' => 'datetime',
        ];
    }

    public function scopeActive(Builder $query): Builder
    {
        return $query->where($query->qualifyColumn('is_active'), true);
    }

    public function scopePublished(Builder $query): Builder
    {
        return $query->active()
            ->whereNotNull($query->qualifyColumn('published_at'))
            ->where($query->qualifyColumn('published_at'), '<=', now());
    }
}
