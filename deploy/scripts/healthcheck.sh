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

api_domain="$(sed -n 's/^APP_DOMAIN=//p' "$env_file" | tail -n 1)"
wordpress_domain="$(sed -n 's/^WORDPRESS_DOMAIN=//p' "$env_file" | tail -n 1)"
if [[ -z "$api_domain" || -z "$wordpress_domain" ]]; then
  echo "APP_DOMAIN or WORDPRESS_DOMAIN is missing from $env_file." >&2
  exit 64
fi

docker compose --project-directory "$deploy_dir" --env-file "$env_file" -f "$compose_file" ps
curl --fail --silent --show-error --max-time 10 "https://${api_domain}/up" >/dev/null
curl --fail --silent --show-error --max-time 10 "https://${wordpress_domain}/" >/dev/null
echo "HTTPS health checks passed for ${api_domain} and ${wordpress_domain}."
