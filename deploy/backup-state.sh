#!/usr/bin/env bash
# State backup: archive the yantresh_state volume (write-ahead ledger +
# daily fuse) so a VPS loss can't wipe the supervisor's spend bounds.
# Run periodically via yantresh-backup.timer. Reads the volume read-only —
# cannot corrupt live state. Rotates, keeping the newest $BACKUP_KEEP.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

# Compose names the volume "<project>_yantresh_state"; project defaults to
# the repo directory name. Override BACKUP_DIR/BACKUP_KEEP/COMPOSE_PROJECT_NAME
# via the systemd unit's Environment= if the defaults don't fit.
PROJECT="${COMPOSE_PROJECT_NAME:-$(basename "$PWD")}"
VOLUME="${PROJECT}_yantresh_state"
DEST="${BACKUP_DIR:-./backups}"
KEEP="${BACKUP_KEEP:-14}"

mkdir -p "$DEST"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
ARCHIVE="yantresh_state_${STAMP}.tar.gz"

# Throwaway alpine tars the volume (read-only) into the host backup dir.
docker run --rm \
  -v "${VOLUME}:/data:ro" \
  -v "$(realpath "$DEST"):/backup" \
  alpine tar czf "/backup/${ARCHIVE}" -C /data .

# Rotate: keep the newest $KEEP archives, delete older ones.
ls -1t "$DEST"/yantresh_state_*.tar.gz 2>/dev/null \
  | tail -n +"$((KEEP + 1))" | xargs -r rm -f

echo "backup: ${DEST}/${ARCHIVE} (keeping ${KEEP})"
