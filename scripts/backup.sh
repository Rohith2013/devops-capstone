#!/bin/bash
# Backs up app container logs and monitoring config. Keeps last 7 days.
set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-$HOME/backups}"
RETENTION_DAYS="${RETENTION_DAYS:-7}"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
WORK_DIR="$(mktemp -d)"
ARCHIVE="$BACKUP_DIR/capstone_backup_$TIMESTAMP.tar.gz"

mkdir -p "$BACKUP_DIR"

echo "[$(date '+%F %T')] Backup started"

# Container logs
docker logs capstone-app > "$WORK_DIR/capstone-app.log" 2>&1 || true

# Monitoring config
cp -r "$HOME/devops-capstone/monitoring" "$WORK_DIR/monitoring"

tar -czf "$ARCHIVE" -C "$WORK_DIR" .
rm -rf "$WORK_DIR"
echo "[$(date '+%F %T')] Created $ARCHIVE"

# Delete backups older than retention period
find "$BACKUP_DIR" -name 'capstone_backup_*.tar.gz' -mtime +"$RETENTION_DAYS" -delete
echo "[$(date '+%F %T')] Backup finished"
