#!/usr/bin/env bash
# Push already-committed work (e.g. lodging.html) to GitHub Pages. Double-click.
# Commits nothing itself, touches no file; pushes main and waits for lodging.html to go live.
set -u
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
DIR="$(cd "$(dirname "$0")" && pwd)"; LOG="$DIR/publish_lodging.log"; : > "$LOG"
log(){ echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG"; }
cd "$DIR" || exit 20
log "=== lodging publish start ==="
git pull --rebase origin main >>"$LOG" 2>&1 || { log "FATAL: pull failed"; read -p "Return to close..."; exit 21; }
git push origin main >>"$LOG" 2>&1 || { log "FATAL: push failed"; read -p "Return to close..."; exit 22; }
log "pushed: $(git rev-parse --short HEAD)"
WANT="$(md5 -q lodging.html)"; URL="https://jzscreative.github.io/greece-2027-islands/lodging.html"
for i in $(seq 1 20); do
  sleep 15
  GOT="$(curl -s -H 'Cache-Control: no-cache' "$URL" | md5 -q)"
  if [ "$GOT" = "$WANT" ]; then log "attempt $i: live md5 matches $WANT"; log "=== publish end: SUCCESS ==="; exit 0; fi
  log "attempt $i: not yet"
done
log "=== publish end: TIMEOUT (push done, Pages not serving it yet) ==="
