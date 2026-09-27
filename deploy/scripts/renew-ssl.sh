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

compose=(docker compose --project-directory "$deploy_dir" --env-file "$env_file" -f "$compose_file")

"${compose[@]}" run --rm --no-deps --entrypoint certbot certbot \
  renew \
  --webroot \
  --webroot-path /var/www/certbot \
  --quiet
"${compose[@]}" exec -T nginx nginx -t
"${compose[@]}" exec -T nginx nginx -s reload
