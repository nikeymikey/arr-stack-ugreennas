#!/bin/bash
# Backup for the arr stack (configs on volume2 -> personal folder on volume1). Run as root.
set -u
PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

DEST_ROOT="/home/Nikeymikey/backups/arr-stack"
STACK="/volume2/docker/arr-stack"
KEEP_DAYS=14
STOP_APPS=1
APPS="sonarr radarr prowlarr bazarr jellyseerr"

[ "$(id -u)" = 0 ] || { echo "Run with sudo" >&2; exit 1; }
[ -d "$(dirname "$DEST_ROOT")" ] || { echo "Create $(dirname "$DEST_ROOT") first" >&2; exit 1; }

DATE=$(date +%Y%m%d)
DEST="$DEST_ROOT/$DATE"
LOG="$DEST_ROOT/backup.log"
FAILED=0
mkdir -p "$DEST" && chmod 700 "$DEST_ROOT" "$DEST"

log()  { echo "[$(date '+%F %T')] $*" | tee -a "$LOG"; }
fail() { log "ERROR: $*"; FAILED=1; }

verify() {
  local f="$DEST/$1.tar.gz"
  if [ ! -s "$f" ] || ! tar -tzf "$f" >/dev/null 2>>"$LOG"; then
    fail "$1: archive missing or unreadable"
  else
    log "ok $1 ($(du -h "$f" | cut -f1))"
  fi
}

backup_dir() {  # name path [tar options]
  local name="$1" path="$2" rc; shift 2
  if [ ! -d "$path" ]; then fail "$name: $path not found"; return; fi
  tar -czf "$DEST/$name.tar.gz" "$@" -C "$(dirname "$path")" "$(basename "$path")" 2>>"$LOG"; rc=$?
  [ "$rc" -gt 1 ] && fail "$name: tar exit $rc"
  verify "$name"
}

backup_volume() {  # docker volume name
  local v="$1"
  if ! docker volume inspect "$v" >/dev/null 2>&1; then fail "volume $v not found"; return; fi
  docker run --rm -v "$v":/source:ro -v "$DEST":/backup alpine:3.20 tar -czf "/backup/$v.tar.gz" -C /source . 2>>"$LOG" \
    || fail "$v: backup command failed"
  verify "$v"
}

restart_apps() {
  log "Starting apps again"
  for a in $APPS; do docker start "$a" >/dev/null || fail "could not start $a"; done
}

log "Backup started"
if [ "$STOP_APPS" = 1 ]; then
  trap restart_apps EXIT
  for a in $APPS; do docker stop "$a" >/dev/null || fail "could not stop $a"; done
fi

backup_dir sonarr-config    /volume2/docker/sonarr/config
backup_dir radarr-config    /volume2/docker/radarr/config
backup_dir bazarr-config    "$STACK/bazarr/config"
backup_dir seerr-config     "$STACK/jellyseerr/config"
backup_dir gluetun-config   "$STACK/gluetun-config"
backup_dir syncthing-config /volume2/docker/syncthing/config
backup_dir thelounge-config /volume2/docker/thelounge
# Jellyfin-HT is copied while running. Add --exclude='*/metadata' if the archive is too large.
backup_dir jellyfin-config  /volume2/docker/jellyfinht/config --exclude='*/transcodes' --exclude='*/log' --exclude='*/cache'

tar -czf "$DEST/stack-files.tar.gz" -C "$STACK" .env traefik/acme.json traefik/traefik.yml traefik/dynamic \
  docker-compose.arr-stack.yml docker-compose.traefik.yml 2>>"$LOG" || fail "stack-files: tar reported errors"
verify stack-files

for v in prowlarr-config pihole-etc-pihole pihole-etc-dnsmasq wireguard-easy-config; do
  backup_volume "arr-stack_$v"
done

if [ "$FAILED" = 0 ]; then
  find "$DEST_ROOT" -maxdepth 1 -type d -name '20??????' -mtime +"$KEEP_DAYS" -exec rm -rf {} +
  log "Backup complete: $DEST"
else
  log "Backup finished WITH ERRORS: old backups kept, see $LOG"
fi
chown -R Nikeymikey "$DEST_ROOT"
exit "$FAILED"