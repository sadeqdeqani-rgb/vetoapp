#!/bin/sh
set -eu

mkdir -p \
  storage/framework/cache/data \
  storage/framework/sessions \
  storage/framework/views \
  storage/logs \
  bootstrap/cache
chown -R www-data:www-data storage bootstrap/cache

if [ "${1:-}" = "/usr/bin/supervisord" ] && [ "${LARAVEL_OPTIMIZE_ON_BOOT:-true}" = "true" ]; then
  php artisan config:cache --no-interaction
  php artisan view:cache --no-interaction
  chown -R www-data:www-data storage bootstrap/cache
fi

exec "$@"
