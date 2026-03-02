#!/bin/bash
# Phoenix SQLite Backup Script
# Backs up Phoenix observability data to timestamped archives

BACKUP_DIR="${PHOENIX_BACKUP_DIR:-/opt/backups/phoenix}"
RETENTION_DAYS="${PHOENIX_BACKUP_RETENTION:-7}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
CONTAINER_NAME="${PHOENIX_CONTAINER:-phoenix-phoenix-1}"
VOLUME_NAME="${PHOENIX_VOLUME:-phoenix_phoenix_data}"

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Stop Phoenix briefly for consistent backup (optional - SQLite WAL mode handles this well)
# docker stop $CONTAINER_NAME 2>/dev/null || true

# Create backup archive
echo "[$TIMESTAMP] Creating Phoenix backup..."
docker run --rm \
    -v "${VOLUME_NAME}:/data:ro" \
    -v "${BACKUP_DIR}:/backup" \
    alpine:latest \
    tar czf "/backup/phoenix_backup_${TIMESTAMP}.tar.gz" -C /data .

# Restart Phoenix if stopped
# docker start $CONTAINER_NAME 2>/dev/null || true

# Clean up old backups (keep last N days)
find "$BACKUP_DIR" -name "phoenix_backup_*.tar.gz" -mtime +$RETENTION_DAYS -delete

# Report
BACKUP_COUNT=$(find "$BACKUP_DIR" -name "phoenix_backup_*.tar.gz" | wc -l)
BACKUP_SIZE=$(du -sh "$BACKUP_DIR" | cut -f1)
echo "[$TIMESTAMP] Backup complete. Total backups: $BACKUP_COUNT, Size: $BACKUP_SIZE"
