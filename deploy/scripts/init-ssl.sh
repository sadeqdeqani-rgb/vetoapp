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

api_domain="$(value_from_env APP_DOMAIN)"
wordpress_domain="$(value_from_env WORDPRESS_DOMAIN)"
wordpress_www_domain="$(value_from_env WORDPRESS_WWW_DOMAIN)"
email="$(value_from_env CERTBOT_EMAIL)"

if [[ -z "$api_domain" || "$api_domain" == *example.com* || -z "$wordpress_domain" || "$wordpress_domain" == *example.com* || -z "$wordpress_www_domain" || "$wordpress_www_domain" == *example.com* || -z "$email" || "$email" == *example.com* ]]; then
  echo "Set real APP_DOMAIN, WORDPRESS_DOMAIN, WORDPRESS_WWW_DOMAIN and CERTBOT_EMAIL values in $env_file before requesting certificates." >&2
  exit 64
fi

if [[ "$api_domain" == "$wordpress_domain" || "$api_domain" == "$wordpress_www_domain" || "$wordpress_domain" == "$wordpress_www_domain" ]]; then
  echo "APP_DOMAIN, WORDPRESS_DOMAIN and WORDPRESS_WWW_DOMAIN must be three distinct hostnames." >&2
  exit 64
fi

compose=(docker compose --project-directory "$deploy_dir" --env-file "$env_file" -f "$compose_file")

"${compose[@]}" up -d --wait nginx
"${compose[@]}" run --rm --no-deps --entrypoint certbot certbot \
  certonly \
  --webroot \
  --webroot-path /var/www/certbot \
  --cert-name "$api_domain" \
  --domain "$api_domain" \
  --email "$email" \
  --agree-tos \
  --no-eff-email \
  --keep-until-expiring \
  --non-interactive
"${compose[@]}" run --rm --no-deps --entrypoint certbot certbot \
  certonly \
  --webroot \
  --webroot-path /var/www/certbot \
  --cert-name "$wordpress_domain" \
  --domain "$wordpress_domain" \
  --domain "$wordpress_www_domain" \
  --email "$email" \
  --agree-tos \
  --no-eff-email \
  --keep-until-expiring \
  --non-interactive
"${compose[@]}" restart nginx
"${compose[@]}" exec -T nginx nginx -t
