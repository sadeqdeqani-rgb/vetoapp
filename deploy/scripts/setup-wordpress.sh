#!/usr/bin/env bash
set -Eeuo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
deploy_dir="$(cd -- "$script_dir/.." && pwd)"
env_file="$deploy_dir/.env.production"
compose_file="$deploy_dir/compose.production.yaml"

if [[ ! -f "$env_file" ]]; then
  echo "Missing $env_file." >&2
  exit 66
fi

value_from_env() {
  local key="$1"
  sed -n "s/^${key}=//p" "$env_file" | tail -n 1
}

require_real_value() {
  local key="$1"
  local value
  value="$(value_from_env "$key")"

  if [[ -z "$value" || "$value" == CHANGE_ME* || "$value" == *example.com* ]]; then
    echo "Set a real value for ${key} in $env_file before installing WordPress." >&2
    exit 64
  fi
}

for key in \
  WORDPRESS_URL \
  WORDPRESS_SITE_TITLE \
  WORDPRESS_ADMIN_USER \
  WORDPRESS_ADMIN_PASSWORD \
  WORDPRESS_ADMIN_EMAIL; do
  require_real_value "$key"
done

compose=(docker compose --project-directory "$deploy_dir" --env-file "$env_file" -f "$compose_file")

"${compose[@]}" up -d --wait wordpress-db wordpress
"${compose[@]}" --profile ops run --rm --no-deps wordpress-theme-sync

if "${compose[@]}" --profile ops run --rm --no-deps wordpress-cli core is-installed --allow-root >/dev/null 2>&1; then
  echo "WordPress is already installed; preserving existing content."
else
  "${compose[@]}" --profile ops run --rm --no-deps wordpress-cli core install \
    --url="$(value_from_env WORDPRESS_URL)" \
    --title="$(value_from_env WORDPRESS_SITE_TITLE)" \
    --admin_user="$(value_from_env WORDPRESS_ADMIN_USER)" \
    --admin_password="$(value_from_env WORDPRESS_ADMIN_PASSWORD)" \
    --admin_email="$(value_from_env WORDPRESS_ADMIN_EMAIL)" \
    --skip-email \
    --allow-root
fi

"${compose[@]}" --profile ops run --rm --no-deps wordpress-cli theme activate vetoapp-landing --allow-root
"${compose[@]}" --profile ops run --rm --no-deps wordpress-cli option update timezone_string Asia/Tehran --allow-root
"${compose[@]}" --profile ops run --rm --no-deps wordpress-cli option update blogdescription 'معرفی محیط وِتواَپ برای مشارکت مدنی و تصمیم‌گیری جمعی' --allow-root
"${compose[@]}" --profile ops run --rm --no-deps wordpress-cli rewrite structure '/%postname%/' --hard --allow-root
"${compose[@]}" --profile ops run --rm --no-deps wordpress-cli cache flush --allow-root

echo "WordPress installation and VetoApp Landing theme setup completed."
