#!/usr/bin/env bash
set -euo pipefail

deb_path="${1:-}"
if [[ -z "${deb_path}" ]]; then
  mapfile -d '' -t candidates < <(find "${HOME}/Downloads" -maxdepth 1 -type f -iname '*gapgpt*.deb' -print0 2>/dev/null)

  latest_mtime=-1
  for candidate in "${candidates[@]}"; do
    mtime="$(stat -c '%Y' "${candidate}")"
    if (( mtime > latest_mtime )); then
      latest_mtime="${mtime}"
      deb_path="${candidate}"
    fi
  done
fi

if [[ -z "${deb_path}" ]]; then
  echo "Error: no .deb path provided and no matching gapgpt .deb found in ~/Downloads." >&2
  exit 1
fi

if [[ ! -f "${deb_path}" ]]; then
  echo "Error: .deb file not found: ${deb_path}" >&2
  exit 1
fi

deb_path="$(readlink -f "${deb_path}")"
architecture="$(dpkg-deb -f "${deb_path}" Architecture)"
if [[ "${architecture}" != "amd64" ]]; then
  echo "Error: unsupported architecture '${architecture}'. This installer requires amd64." >&2
  exit 1
fi

package_name="$(dpkg-deb -f "${deb_path}" Package)"
package_version="$(dpkg-deb -f "${deb_path}" Version)"

sudo apt update
sudo apt install -y "${deb_path}"

echo "Installed ${package_name} ${package_version=} successfully."
echo "Uninstall: sudo apt remove -y ${package_name}"