#!/bin/bash
# Deletes old backups and prunes unused Docker data.
set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-$HOME/backups}"
DAYS="${DAYS:-14}"

echo "[$(date '+%F %T')] Cleanup started"

if [ -d "$BACKUP_DIR" ]; then
  COUNT=$(find "$BACKUP_DIR" -type f -name '*.tar.gz' -mtime +"$DAYS" | wc -l)
  find "$BACKUP_DIR" -type f -name '*.tar.gz' -mtime +"$DAYS" -delete
  echo "Removed $COUNT backup file(s) older than $DAYS days"
fi

# Remove stopped containers and dangling images
docker container prune -f
docker image prune -f

echo "[$(date '+%F %T')] Cleanup finished"
