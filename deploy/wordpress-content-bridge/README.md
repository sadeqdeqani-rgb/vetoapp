# VetoApp WordPress Content Bridge

This plugin exposes an authenticated WordPress REST API used only by the Laravel admin API. It supports the landing theme's existing option record, existing public pages, the `vetoapp_feature`, `vetoapp_preview`, and `vetoapp_faq` collections, and image uploads to the WordPress media library.

## Access model

- The Flutter admin panel authenticates only to Laravel.
- Laravel stores the WordPress Application Password in its server environment and sends it to WordPress over HTTPS.
- The plugin creates a `vetoapp_content_manager` role with page/content edit and image upload capabilities plus the `manage_vetoapp_content` capability.
- The plugin API rejects callers without that capability. No WordPress credential is sent to the browser.

## Install on the WordPress host

Run the packaged `install-plugin.sh` with the WordPress deployment directory. It backs up an existing plugin file, copies the new plugin into the persistent WordPress data directory, and activates it through WP-CLI.

Create a dedicated WordPress user with the `مدیر محتوای وتواپ` role, then create an Application Password for that account over the WordPress profile page. Configure the following values in the Laravel API environment, never in Flutter or a public file:

```dotenv
WORDPRESS_CONTENT_API_URL=https://vetoapp.net
WORDPRESS_CONTENT_API_USERNAME=<dedicated-user>
WORDPRESS_CONTENT_API_PASSWORD=<application-password>
WORDPRESS_CONTENT_API_TIMEOUT=20
```

After setting them, clear Laravel's configuration cache and recreate the API container using the existing deployment procedure. Verify `GET /api/admin/wordpress/content` from the authenticated admin panel.

The bridge does not expose arbitrary WordPress options or direct database access. Settings updates are limited to keys already present in `vetoapp_landing_options`.
