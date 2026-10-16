#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "Usage: sudo bash $0 /opt/vetoapp-wordpress/deployment" >&2
    exit 2
fi

wordpress_deploy=${1%/}
compose_file="$wordpress_deploy/compose.wordpress.yaml"
source_file="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/vetoapp-content-bridge.php"
plugin_dir="$wordpress_deploy/data/wp-content/plugins/vetoapp-content-bridge"

[[ -f "$compose_file" ]] || { echo "Compose file not found: $compose_file" >&2; exit 1; }
[[ -f "$source_file" ]] || { echo "Plugin source not found: $source_file" >&2; exit 1; }

mkdir -p "$plugin_dir"
if [[ -f "$plugin_dir/vetoapp-content-bridge.php" ]]; then
    backup="$plugin_dir/vetoapp-content-bridge.php.before-$(date -u +%Y%m%dT%H%M%SZ)"
    cp -a "$plugin_dir/vetoapp-content-bridge.php" "$backup"
    echo "Previous plugin file backed up to: $backup"
fi

install -m 0644 "$source_file" "$plugin_dir/vetoapp-content-bridge.php"
docker compose --project-directory "$wordpress_deploy" \
    -f "$compose_file" exec -T wordpress \
    wp --allow-root --path=/var/www/html plugin activate vetoapp-content-bridge

echo 'VetoApp Content Bridge installed and activated.'
