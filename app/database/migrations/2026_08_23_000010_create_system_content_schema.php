<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    private function configure(Blueprint $table): void
    {
        $table->engine = 'InnoDB';
        $table->charset = 'utf8mb4';
        $table->collation = 'utf8mb4_0900_ai_ci';
    }

    public function up(): void
    {
        Schema::create('system_introduction_contents', function (Blueprint $table): void {
            $this->configure($table);
            $table->unsignedSmallInteger('introduction_content_id')->autoIncrement();
            $table->unsignedInteger('version_number');
            $table->string('title', 255);
            $table->longText('body_text');
            $table->boolean('is_active')->default(false);
            $table->dateTime('published_at')->nullable();
            $table->dateTime('created_at')->useCurrent();
            $table->dateTime('updated_at')->useCurrent()->useCurrentOnUpdate();

            $table->unique('version_number', 'uq_system_intro_version');
            $table->index(['is_active', 'published_at'], 'idx_system_intro_active_published');
        });

        Schema::create('system_terms_contents', function (Blueprint $table): void {
            $this->configure($table);
            $table->unsignedSmallInteger('terms_content_id')->autoIncrement();
            $table->unsignedInteger('version_number');
            $table->string('title', 255);
            $table->longText('body_text');
            $table->boolean('is_active')->default(false);
            $table->dateTime('published_at')->nullable();
            $table->dateTime('created_at')->useCurrent();
            $table->dateTime('updated_at')->useCurrent()->useCurrentOnUpdate();

            $table->unique('version_number', 'uq_system_terms_version');
            $table->index(['is_active', 'published_at'], 'idx_system_terms_active_published');
        });

        Schema::create('system_introduction_videos', function (Blueprint $table): void {
            $this->configure($table);
            $table->unsignedSmallInteger('introduction_video_id')->autoIncrement();
            $table->unsignedInteger('version_number');
            $table->string('title', 255);
            $table->string('video_url', 2048);
            $table->string('poster_url', 2048)->nullable();
            $table->unsignedInteger('duration_seconds')->nullable();
            $table->boolean('is_active')->default(false);
            $table->dateTime('published_at')->nullable();
            $table->dateTime('created_at')->useCurrent();
            $table->dateTime('updated_at')->useCurrent()->useCurrentOnUpdate();

            $table->unique('version_number', 'uq_system_intro_video_version');
            $table->index(['is_active', 'published_at'], 'idx_system_intro_video_active_published');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('system_introduction_videos');
        Schema::dropIfExists('system_terms_contents');
        Schema::dropIfExists('system_introduction_contents');
    }
};
