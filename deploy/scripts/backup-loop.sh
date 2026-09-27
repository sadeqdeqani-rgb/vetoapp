#!/bin/sh
set -eu

interval="${BACKUP_INTERVAL_SECONDS:-86400}"

case "$interval" in
  ''|*[!0-9]*|0)
    echo "BACKUP_INTERVAL_SECONDS must be a positive integer." >&2
    exit 64
    ;;
esac

while true; do
  if ! /usr/local/bin/vetoapp-backup; then
    echo "Backup failed; retrying in 300 seconds." >&2
    sleep 300
    continue
  fi

  sleep "$interval"
done
