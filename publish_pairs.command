#!/usr/bin/env bash
# Publish ONLY pairs.html to GitHub Pages.
# Double-click this file. It does not touch index.html, README.md or photos/,
# so the existing publish.sh flow for the trip page is unaffected.
set -u
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
DIR="$(cd "$(dirname "$0")" && pwd)"
LOG="$DIR/publish_pairs.log"
: > "$LOG"
log(){ echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG"; }
run(){ log "\$ $*"; "$@" >>"$LOG" 2>&1; rc=$?; log "  -> exit $rc"; return $rc; }

REPO_NAME="greece-2027-islands"
cd "$DIR" || exit 20
log "=== pairs page publish start ==="
log "repo: $DIR"

command -v gh  >/dev/null || { log "FATAL: gh not installed";  read -p "Return to close..."; exit 10; }
command -v git >/dev/null || { log "FATAL: git not installed"; read -p "Return to close..."; exit 11; }
gh auth status >>"$LOG" 2>&1 || { log "FATAL: gh not authenticated. Run 'gh auth login'."; read -p "Return to close..."; exit 12; }
GH_USER="$(gh api user --jq .login 2>>"$LOG")"
[ -n "$GH_USER" ] || { log "FATAL: could not resolve gh user"; read -p "Return to close..."; exit 13; }
log "gh user: $GH_USER"
[ -f pairs.html ] || { log "FATAL: pairs.html not found in $DIR"; read -p "Return to close..."; exit 14; }

# restamp version + time so the header can never go stale
STAMP="$(python3 - pairs.html <<'PYEOF'
import io,re,sys
from datetime import datetime
from zoneinfo import ZoneInfo
p=sys.argv[1]; s=io.open(p,encoding="utf-8").read()
now=datetime.now(ZoneInfo("America/New_York")); c=now.strftime("%y%m%d %H%M")
s=re.sub(r'(<title>Greece 2027 · Island Pairs · )[^<]*(</title>)', lambda m:m.group(1)+c+m.group(2), s, count=1)
s=re.sub(r'(<span class="ver">v[0-9A-Za-z.\-]+ &middot; )[^<]*( ET</span>)', lambda m:m.group(1)+c+m.group(2), s, count=1)
io.open(p,"w",encoding="utf-8").write(s); print(c)
PYEOF
)"
EXPECT_TITLE="Greece 2027 · Island Pairs · $STAMP"
log "stamped: $STAMP"

MSG="${1:-pairs page: island pair shortlist, $STAMP ET}"
run git fetch --all --prune || true
run git checkout main || run git checkout -b main
run git pull --ff-only origin main || true
run git add -- pairs.html .gitignore publish_pairs.command
if git diff --cached --quiet; then log "no changes to commit"; else run git commit -m "$MSG"; fi
run git push -u origin main || { log "FATAL: push failed"; read -p "Return to close..."; exit 22; }

URL="https://$GH_USER.github.io/$REPO_NAME/pairs.html"
log "expected URL: $URL"
log "waiting for THIS build (title: $EXPECT_TITLE)"
LIVE=0
for i in $(seq 1 20); do
  sleep 15
  CODE=$(curl -s -o /dev/null -w "%{http_code}" -I "$URL" || echo "000")
  HEAD=$(curl -s -r 0-2047 -H "Cache-Control: no-cache" "$URL" 2>/dev/null || true)
  if echo "$HEAD" | grep -qF "$EXPECT_TITLE"; then
    log "attempt $i -> HTTP $CODE | serving this build OK"
    log "LIVE: $URL"; LIVE=1; break
  fi
  SERVING=$(echo "$HEAD" | sed -n 's/.*<title>\(.*\)<\/title>.*/\1/p' | head -1)
  log "attempt $i -> HTTP $CODE | serving: ${SERVING:-<unknown>}"
done
echo "$URL" > "$DIR/pairs_live_url.txt"
[ "$LIVE" -eq 1 ] && log "=== publish end: SUCCESS ===" || log "=== publish end: STALE. See $LOG ==="
echo ""
read -p "Press Return to close..."
