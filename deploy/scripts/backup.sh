#!/bin/sh
set -eu

umask 077

: "${DB_HOST:?DB_HOST is required}"
: "${DB_PORT:?DB_PORT is required}"
: "${DB_DATABASE:?DB_DATABASE is required}"
: "${DB_USERNAME:?DB_USERNAME is required}"
: "${DB_PASSWORD:?DB_PASSWORD is required}"

backup_dir="${BACKUP_DIR:-/backups}"
metrics_dir="${BACKUP_METRICS_DIR:-/metrics}"
retention_days="${BACKUP_RETENTION_DAYS:-14}"

case "$retention_days" in
  ''|*[!0-9]*)
    echo "BACKUP_RETENTION_DAYS must be a non-negative integer." >&2
    exit 64
    ;;
esac

mkdir -p "$backup_dir" "$metrics_dir"

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
temporary_file="$backup_dir/.vetoapp-${timestamp}.sql.gz.tmp"
backup_file="$backup_dir/vetoapp-${timestamp}.sql.gz"

export MYSQL_PWD="$DB_PASSWORD"
mysqldump \
  --host="$DB_HOST" \
  --port="$DB_PORT" \
  --user="$DB_USERNAME" \
  --single-transaction \
  --quick \
  --routines \
  --events \
  --triggers \
  --default-character-set=utf8mb4 \
  "$DB_DATABASE" | gzip -9 > "$temporary_file"
unset MYSQL_PWD

gzip -t "$temporary_file"

if [ -n "${BACKUP_ENCRYPTION_PASSPHRASE:-}" ]; then
  encrypted_file="${backup_file}.enc"
  openssl enc -aes-256-cbc -salt -pbkdf2 -iter 200000 \
    -pass env:BACKUP_ENCRYPTION_PASSPHRASE \
    -in "$temporary_file" \
    -out "${encrypted_file}.tmp"
  rm -f "$temporary_file"
  mv "${encrypted_file}.tmp" "$encrypted_file"
  backup_file="$encrypted_file"
else
  mv "$temporary_file" "$backup_file"
fi

sha256sum "$backup_file" > "${backup_file}.sha256"
find "$backup_dir" -maxdepth 1 -type f -name 'vetoapp-*' -mtime "+$retention_days" -delete

metrics_file="$metrics_dir/vetoapp_backup.prom"
metrics_temporary_file="${metrics_file}.tmp"
{
  echo '# HELP vetoapp_backup_last_success_unixtime Unix time of the latest completed database backup.'
  echo '# TYPE vetoapp_backup_last_success_unixtime gauge'
  printf 'vetoapp_backup_last_success_unixtime %s\n' "$(date -u +%s)"
  echo '# HELP vetoapp_backup_last_size_bytes Size in bytes of the latest database backup.'
  echo '# TYPE vetoapp_backup_last_size_bytes gauge'
  printf 'vetoapp_backup_last_size_bytes %s\n' "$(wc -c < "$backup_file")"
} > "$metrics_temporary_file"
mv "$metrics_temporary_file" "$metrics_file"

echo "Backup completed: $backup_file"
