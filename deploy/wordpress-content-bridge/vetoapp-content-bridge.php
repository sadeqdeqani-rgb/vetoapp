<?php
/**
 * Plugin Name: VetoApp Content Bridge
 * Description: Exposes a narrow, authenticated content-management API for the VetoApp admin panel.
 * Version: 1.0.0
 * Requires at least: 6.0
 * Requires PHP: 8.0
 * License: GPL-2.0-or-later
 */

declare(strict_types=1);

if (! defined('ABSPATH')) {
    exit;
}

final class VetoApp_Content_Bridge
{
    private const NAMESPACE = 'vetoapp-admin/v1';
    private const OPTION_NAME = 'vetoapp_landing_options';
    private const COLLECTIONS = [
        'features' => 'vetoapp_feature',
        'previews' => 'vetoapp_preview',
        'faqs' => 'vetoapp_faq',
    ];

    public static function boot(): void
    {
        add_action('rest_api_init', [self::class, 'routes']);
        add_action('template_redirect', [self::class, 'start_home_image_buffer'], 0);
    }

    public static function activate(): void
    {
        $capabilities = [
            'read' => true,
            'upload_files' => true,
            'manage_vetoapp_content' => true,
            'edit_pages' => true,
            'edit_others_pages' => true,
            'edit_published_pages' => true,
            'publish_pages' => true,
            'edit_posts' => true,
            'edit_others_posts' => true,
            'edit_published_posts' => true,
            'publish_posts' => true,
        ];
        $role = get_role('vetoapp_content_manager');
        if ($role === null) {
            add_role('vetoapp_content_manager', 'مدیر محتوای وتواپ', $capabilities);
            return;
        }
        foreach ($capabilities as $capability => $grant) {
            if ($grant) {
                $role->add_cap($capability);
            }
        }
    }

    public static function routes(): void
    {
        register_rest_route(self::NAMESPACE, '/content', [
            'methods' => WP_REST_Server::READABLE,
            'callback' => [self::class, 'content'],
            'permission_callback' => [self::class, 'can_manage_content'],
        ]);
        register_rest_route(self::NAMESPACE, '/settings', [
            'methods' => 'PUT',
            'callback' => [self::class, 'update_settings'],
            'permission_callback' => [self::class, 'can_manage_content'],
            'args' => ['settings' => ['required' => true, 'type' => 'object']],
        ]);
        register_rest_route(self::NAMESPACE, '/pages/(?P<id>\d+)', [
            'methods' => 'PATCH',
            'callback' => [self::class, 'update_page'],
            'permission_callback' => [self::class, 'can_manage_content'],
            'args' => ['id' => ['required' => true, 'validate_callback' => 'is_numeric']],
        ]);
        register_rest_route(self::NAMESPACE, '/collections/(?P<type>features|previews|faqs)/(?P<id>\d+)', [
            'methods' => 'PATCH',
            'callback' => [self::class, 'update_collection_item'],
            'permission_callback' => [self::class, 'can_manage_content'],
            'args' => [
                'type' => ['required' => true],
                'id' => ['required' => true, 'validate_callback' => 'is_numeric'],
            ],
        ]);
        register_rest_route(self::NAMESPACE, '/media', [
            'methods' => WP_REST_Server::CREATABLE,
            'callback' => [self::class, 'upload_media'],
            'permission_callback' => [self::class, 'can_manage_content'],
        ]);
    }

    public static function can_manage_content(): bool
    {
        $isContentManager = current_user_can('manage_vetoapp_content');
        $isAdministrator = current_user_can('manage_options');

        return ($isContentManager || $isAdministrator) && current_user_can('upload_files');
    }

    public static function content(): WP_REST_Response
    {
        $settings = get_option(self::OPTION_NAME, []);
        $settings = is_array($settings) ? $settings : [];
        $heroImageId = (int) get_option('vetoapp_home_hero_image_id', 0);
        $settings['hero_image_id'] = (string) $heroImageId;

        return new WP_REST_Response([
            'data' => [
                'settings' => $settings,
                'hero_image_url' => $heroImageId > 0 ? (string) wp_get_attachment_image_url($heroImageId, 'large') : '',
                'pages' => self::posts('page'),
                'collections' => [
                    'features' => self::posts(self::COLLECTIONS['features']),
                    'previews' => self::posts(self::COLLECTIONS['previews']),
                    'faqs' => self::posts(self::COLLECTIONS['faqs']),
                ],
            ],
        ]);
    }

    public static function update_settings(WP_REST_Request $request): WP_REST_Response|WP_Error
    {
        $current = get_option(self::OPTION_NAME, []);
        $current = is_array($current) ? $current : [];
        $incoming = $request->get_param('settings');
        if (! is_array($incoming) || $incoming === []) {
            return new WP_Error('vetoapp_invalid_settings', 'تنظیمات ارسالی معتبر نیست.', ['status' => 422]);
        }

        $heroImageId = (int) get_option('vetoapp_home_hero_image_id', 0);
        $updateHeroImage = false;
        foreach ($incoming as $key => $value) {
            if (! is_string($key)) {
                return new WP_Error('vetoapp_unknown_setting', 'یکی از فیلدهای تنظیمات شناخته‌شده نیست.', ['status' => 422]);
            }
            if (! is_string($value) && $value !== null) {
                return new WP_Error('vetoapp_invalid_setting_value', 'مقدار یکی از فیلدها معتبر نیست.', ['status' => 422]);
            }

            if ($key === 'hero_image_id') {
                $rawId = (string) ($value ?? '0');
                if (! ctype_digit($rawId)) {
                    return new WP_Error('vetoapp_invalid_media', 'شناسهٔ تصویر اصلی معتبر نیست.', ['status' => 422]);
                }
                $heroImageId = (int) $rawId;
                if ($heroImageId > 0 && ! wp_attachment_is_image($heroImageId)) {
                    return new WP_Error('vetoapp_invalid_media', 'فایل انتخاب‌شده تصویر معتبر نیست.', ['status' => 422]);
                }
                $updateHeroImage = true;
                continue;
            }
            if (! array_key_exists($key, $current)) {
                return new WP_Error('vetoapp_unknown_setting', 'یکی از فیلدهای تنظیمات شناخته‌شده نیست.', ['status' => 422]);
            }
            $current[$key] = self::sanitize_setting($key, (string) ($value ?? ''));
        }

        // Preserve the theme's own registered sanitizer when it is available.
        $current = sanitize_option(self::OPTION_NAME, $current);
        if (! is_array($current)) {
            return new WP_Error('vetoapp_invalid_settings', 'تنظیمات سایت معتبر نیست.', ['status' => 422]);
        }
        update_option(self::OPTION_NAME, $current, false);
        if ($updateHeroImage) {
            update_option('vetoapp_home_hero_image_id', $heroImageId, false);
        }
        $responseSettings = $current;
        $responseSettings['hero_image_id'] = (string) $heroImageId;

        return new WP_REST_Response(['data' => ['settings' => $responseSettings]]);
    }

    public static function start_home_image_buffer(): void
    {
        if (! is_front_page() || (int) get_option('vetoapp_home_hero_image_id', 0) < 1) {
            return;
        }

        ob_start([self::class, 'replace_home_image']);
    }

    public static function replace_home_image(string $html): string
    {
        $attachmentId = (int) get_option('vetoapp_home_hero_image_id', 0);
        $replacement = $attachmentId > 0 ? wp_get_attachment_image_url($attachmentId, 'large') : false;
        if (! is_string($replacement) || $replacement === '') {
            return $html;
        }

        $themeImage = trailingslashit(get_template_directory_uri()).'assets/images/persianmap.png';
        $pattern = "~".preg_quote($themeImage, '~')."(?:%3F[^\"'\\s>]*|\\?[^\"'\\s>]*)?~i";

        return (string) preg_replace($pattern, esc_url($replacement), $html);
    }

    public static function update_page(WP_REST_Request $request): WP_REST_Response|WP_Error
    {
        $post = get_post((int) $request['id']);
        if (! $post instanceof WP_Post || $post->post_type !== 'page') {
            return new WP_Error('vetoapp_page_not_found', 'برگه پیدا نشد.', ['status' => 404]);
        }
        if (! current_user_can('edit_post', $post->ID)) {
            return new WP_Error('vetoapp_page_forbidden', 'اجازهٔ ویرایش این برگه وجود ندارد.', ['status' => 403]);
        }

        if ($request->has_param('featured_media')) {
            $mediaId = (int) $request->get_param('featured_media');
            if ($mediaId > 0 && ! wp_attachment_is_image($mediaId)) {
                return new WP_Error('vetoapp_invalid_media', 'تصویر شاخص معتبر نیست.', ['status' => 422]);
            }
        }

        $fields = self::post_fields($request);
        if ($fields !== []) {
            $fields['ID'] = $post->ID;
            $updated = wp_update_post($fields, true);
            if (is_wp_error($updated)) {
                return $updated;
            }
        }

        if ($request->has_param('featured_media')) {
            $mediaId = (int) $request->get_param('featured_media');
            if ($mediaId > 0) {
                set_post_thumbnail($post->ID, $mediaId);
            } else {
                delete_post_thumbnail($post->ID);
            }
        }
        if ($request->has_param('subtitle')) {
            update_post_meta($post->ID, 'vetoapp_page_subtitle', sanitize_textarea_field((string) $request->get_param('subtitle')));
        }

        return new WP_REST_Response(['data' => self::serialize_post(get_post($post->ID))]);
    }

    public static function update_collection_item(WP_REST_Request $request): WP_REST_Response|WP_Error
    {
        $type = (string) $request['type'];
        $postType = self::COLLECTIONS[$type] ?? null;
        $post = get_post((int) $request['id']);
        if (! is_string($postType) || ! $post instanceof WP_Post || $post->post_type !== $postType) {
            return new WP_Error('vetoapp_content_not_found', 'محتوا پیدا نشد.', ['status' => 404]);
        }
        if (! current_user_can('edit_post', $post->ID)) {
            return new WP_Error('vetoapp_content_forbidden', 'اجازهٔ ویرایش این محتوا وجود ندارد.', ['status' => 403]);
        }

        if ($request->has_param('featured_media')) {
            $mediaId = (int) $request->get_param('featured_media');
            if ($mediaId > 0 && ! wp_attachment_is_image($mediaId)) {
                return new WP_Error('vetoapp_invalid_media', 'تصویر شاخص معتبر نیست.', ['status' => 422]);
            }
        }

        $fields = self::post_fields($request);
        if ($fields !== []) {
            $fields['ID'] = $post->ID;
            $updated = wp_update_post($fields, true);
            if (is_wp_error($updated)) {
                return $updated;
            }
        }
        if ($request->has_param('featured_media')) {
            $mediaId = (int) $request->get_param('featured_media');
            if ($mediaId > 0) {
                set_post_thumbnail($post->ID, $mediaId);
            } else {
                delete_post_thumbnail($post->ID);
            }
        }

        if ($type === 'features' && $request->has_param('icon')) {
            update_post_meta($post->ID, 'vetoapp_feature_icon', sanitize_key((string) $request->get_param('icon')));
        }
        if ($type === 'faqs') {
            if ($request->has_param('resource_url')) {
                update_post_meta($post->ID, 'vetoapp_faq_resource_url', esc_url_raw((string) $request->get_param('resource_url'), ['https']));
            }
            if ($request->has_param('resource_label')) {
                update_post_meta($post->ID, 'vetoapp_faq_resource_label', sanitize_text_field((string) $request->get_param('resource_label')));
            }
        }

        return new WP_REST_Response(['data' => self::serialize_post(get_post($post->ID), $type)]);
    }

    public static function upload_media(WP_REST_Request $request): WP_REST_Response|WP_Error
    {
        if (! current_user_can('upload_files')) {
            return new WP_Error('vetoapp_upload_forbidden', 'اجازهٔ بارگذاری رسانه وجود ندارد.', ['status' => 403]);
        }
        if (empty($_FILES['file'])) {
            return new WP_Error('vetoapp_upload_missing', 'فایل تصویر دریافت نشد.', ['status' => 422]);
        }
        $file = $_FILES['file'];
        if (! is_array($file)
            || (int) ($file['error'] ?? UPLOAD_ERR_NO_FILE) !== UPLOAD_ERR_OK
            || (int) ($file['size'] ?? 0) < 1
            || (int) ($file['size'] ?? 0) > 10 * 1024 * 1024
            || ! is_string($file['tmp_name'] ?? null)
            || ! is_uploaded_file($file['tmp_name'])) {
            return new WP_Error('vetoapp_upload_invalid', 'فایل بارگذاری‌شده معتبر نیست یا از اندازهٔ مجاز بزرگ‌تر است.', ['status' => 422]);
        }

        $fileType = wp_check_filetype_and_ext($file['tmp_name'], (string) ($file['name'] ?? ''));
        if (! in_array($fileType['type'] ?? '', ['image/jpeg', 'image/png', 'image/webp', 'image/gif'], true)) {
            return new WP_Error('vetoapp_upload_type', 'فقط تصویرهای JPEG، PNG، WebP و GIF پذیرفته می‌شوند.', ['status' => 422]);
        }

        require_once ABSPATH.'wp-admin/includes/file.php';
        require_once ABSPATH.'wp-admin/includes/media.php';
        require_once ABSPATH.'wp-admin/includes/image.php';

        $attachmentId = media_handle_upload('file', 0);
        if (is_wp_error($attachmentId)) {
            return $attachmentId;
        }

        return new WP_REST_Response([
            'data' => [
                'id' => (int) $attachmentId,
                'source_url' => wp_get_attachment_url($attachmentId),
                'mime_type' => get_post_mime_type($attachmentId),
                'alt_text' => get_post_meta($attachmentId, '_wp_attachment_image_alt', true),
            ],
        ], 201);
    }

    private static function posts(string $postType): array
    {
        $query = new WP_Query([
            'post_type' => $postType,
            'post_status' => ['publish', 'draft', 'pending', 'private'],
            'posts_per_page' => 200,
            'orderby' => ['menu_order' => 'ASC', 'date' => 'DESC'],
            'no_found_rows' => true,
        ]);

        return array_map(
            static fn (WP_Post $post): array => self::serialize_post($post, $postType),
            $query->posts,
        );
    }

    private static function serialize_post(WP_Post $post, ?string $collection = null): array
    {
        $mediaId = (int) get_post_thumbnail_id($post->ID);
        $data = [
            'id' => $post->ID,
            'type' => $post->post_type,
            'title' => $post->post_title,
            'content' => $post->post_content,
            'excerpt' => $post->post_excerpt,
            'slug' => $post->post_name,
            'status' => $post->post_status,
            'menu_order' => (int) $post->menu_order,
            'featured_media' => $mediaId,
            'featured_image_url' => $mediaId > 0 ? (string) wp_get_attachment_image_url($mediaId, 'large') : '',
        ];

        if ($post->post_type === 'page') {
            $data['subtitle'] = (string) get_post_meta($post->ID, 'vetoapp_page_subtitle', true);
        }
        if ($collection === 'vetoapp_feature') {
            $data['icon'] = (string) get_post_meta($post->ID, 'vetoapp_feature_icon', true);
        }
        if ($collection === 'vetoapp_faq') {
            $data['resource_url'] = (string) get_post_meta($post->ID, 'vetoapp_faq_resource_url', true);
            $data['resource_label'] = (string) get_post_meta($post->ID, 'vetoapp_faq_resource_label', true);
        }

        return $data;
    }

    private static function post_fields(WP_REST_Request $request): array
    {
        $fields = [];
        if ($request->has_param('title')) {
            $fields['post_title'] = sanitize_text_field((string) $request->get_param('title'));
        }
        if ($request->has_param('content')) {
            $fields['post_content'] = wp_kses_post((string) $request->get_param('content'));
        }
        if ($request->has_param('excerpt')) {
            $fields['post_excerpt'] = sanitize_textarea_field((string) $request->get_param('excerpt'));
        }
        if ($request->has_param('status')) {
            $fields['post_status'] = in_array($request->get_param('status'), ['publish', 'draft'], true)
                ? (string) $request->get_param('status')
                : 'draft';
        }
        if ($request->has_param('menu_order')) {
            $fields['menu_order'] = (int) $request->get_param('menu_order');
        }

        return $fields;
    }

    private static function sanitize_setting(string $key, string $value): string
    {
        if (str_ends_with($key, '_url')) {
            return esc_url_raw($value, wp_allowed_protocols());
        }
        if (str_contains($key, 'email')) {
            return sanitize_email($value);
        }

        return sanitize_textarea_field($value);
    }
}

VetoApp_Content_Bridge::boot();
register_activation_hook(__FILE__, [VetoApp_Content_Bridge::class, 'activate']);
