#!/usr/bin/env bash
set -Eeuo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
deploy_dir="$(cd -- "$script_dir/.." && pwd)"
env_file="$deploy_dir/.env.production"
compose_file="$deploy_dir/compose.production.yaml"

seed=false
monitoring=false

usage() {
  echo "Usage: bash scripts/release.sh [--seed] [--monitoring]" >&2
}

for argument in "$@"; do
  case "$argument" in
    --seed) seed=true ;;
    --monitoring) monitoring=true ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage
      exit 64
      ;;
  esac
done

if [[ ! -f "$env_file" ]]; then
  echo "Missing $env_file. Copy .env.production.example and set all secrets first." >&2
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
    echo "Set a real value for ${key} in $env_file before deploying." >&2
    exit 64
  fi
}

for key in \
  APP_DOMAIN \
  APP_URL \
  APP_KEY \
  MYSQL_PASSWORD \
  MYSQL_ROOT_PASSWORD \
  VALKEY_PASSWORD \
  WORDPRESS_DOMAIN \
  WORDPRESS_WWW_DOMAIN \
  WORDPRESS_URL \
  WORDPRESS_DB_PASSWORD \
  WORDPRESS_DB_ROOT_PASSWORD \
  WORDPRESS_AUTH_KEY \
  WORDPRESS_SECURE_AUTH_KEY \
  WORDPRESS_LOGGED_IN_KEY \
  WORDPRESS_NONCE_KEY \
  WORDPRESS_AUTH_SALT \
  WORDPRESS_SECURE_AUTH_SALT \
  WORDPRESS_LOGGED_IN_SALT \
  WORDPRESS_NONCE_SALT; do
  require_real_value "$key"
done

if [[ -z "$(value_from_env WORDPRESS_BUILD_CONTEXT)" || -z "$(value_from_env WORDPRESS_DOCKERFILE)" ]]; then
  echo "Set WORDPRESS_BUILD_CONTEXT and WORDPRESS_DOCKERFILE in $env_file before deploying." >&2
  exit 64
fi

if [[ "$(value_from_env DB_PASSWORD)" != "$(value_from_env MYSQL_PASSWORD)" ]]; then
  echo "DB_PASSWORD must match MYSQL_PASSWORD." >&2
  exit 64
fi

if [[ "$(value_from_env REDIS_PASSWORD)" != "$(value_from_env VALKEY_PASSWORD)" ]]; then
  echo "REDIS_PASSWORD must match VALKEY_PASSWORD." >&2
  exit 64
fi

compose=(docker compose --project-directory "$deploy_dir" --env-file "$env_file" -f "$compose_file")

"${compose[@]}" config --quiet
"${compose[@]}" build app nginx wordpress
"${compose[@]}" up -d --wait mysql valkey wordpress-db
"${compose[@]}" run --rm --no-deps migrate

if [[ "$seed" == true ]]; then
  "${compose[@]}" run --rm --no-deps seed
fi

"${compose[@]}" up -d --wait app queue scheduler telegram-poller wordpress nginx backup wordpress-backup
"${compose[@]}" --profile ops run --rm --no-deps wordpress-theme-sync
"${compose[@]}" exec -T queue php artisan queue:restart --no-interaction || true

if [[ "$monitoring" == true ]]; then
  "${compose[@]}" --profile monitoring up -d --wait prometheus blackbox node-exporter
fi

"${compose[@]}" ps
