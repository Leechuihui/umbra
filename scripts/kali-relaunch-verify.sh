#!/usr/bin/env bash
# Relaunch the client with DevTools, clear old listeners, and report state.

set -uo pipefail

ROOT=/home/myroot/umbra
GUI="$ROOT/client/gui"
BASE=http://127.0.0.1:9000
export DISPLAY=:0
export XAUTHORITY=/home/myroot/.Xauthority

echo "=== 1. ensure the server is up ==="
if ! ss -ltn 2>/dev/null | grep -q ':9000'; then
  echo "  starting server..."
  cd "$ROOT" || exit 1
  setsid nohup ./umbra.py server start > /tmp/umbra-server.log 2>&1 < /dev/null &
  for i in $(seq 1 30); do
    ss -ltn 2>/dev/null | grep -q ':9000' && break
    sleep 1
  done
fi
ss -ltn 2>/dev/null | grep -q ':9000' && echo "  server listening" || { echo "  SERVER DOWN"; exit 1; }

echo
echo "=== 2. clear existing listeners ==="
KEY=$(head -1 "$ROOT/admin.key")
U="${KEY%%:*}"; R="${KEY#*:}"; P="${R%%:*}"; S="${R#*:}"

TOKEN=$(curl -s -X POST "$BASE/auth/login" \
  -H 'Content-Type: application/json' \
  -d "{\"user\":\"$U\",\"pass\":\"$P\",\"secret\":\"$S\"}" 2>/dev/null \
  | python3 -c 'import json,sys; print(json.load(sys.stdin).get("access_token") or "")' 2>/dev/null)

LIST=$(curl -s "$BASE/api/listeners/" -H "Authorization: Bearer $TOKEN" 2>/dev/null)
TAGS=$(echo "$LIST" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
for it in (d.get("active_channels") or []):
    tag = it.get("tag") or it.get("name")
    if tag:
        print(tag)
' 2>/dev/null)

if [[ -z "$TAGS" ]]; then
  echo "  none to remove"
else
  while IFS= read -r tag; do
    [[ -z "$tag" ]] && continue
    code=$(curl -s -o /dev/null -w '%{http_code}' -X DELETE "$BASE/api/listeners/$tag" \
      -H "Authorization: Bearer $TOKEN" 2>/dev/null)
    echo "  removed $tag -> HTTP $code"
  done <<< "$TAGS"
fi

echo
echo "=== 3. relaunch the client with DevTools ==="
cd "$GUI/dist" || exit 1
setsid nohup ./umbra.AppImage \
  --appimage-extract-and-run \
  --no-sandbox \
  --remote-debugging-port=9222 \
  --remote-allow-origins='*' \
  > /tmp/umbra-client.log 2>&1 < /dev/null &

for i in $(seq 1 40); do
  curl -s --max-time 2 http://127.0.0.1:9222/json/version >/dev/null 2>&1 && { echo "  debug port up after ${i}s"; break; }
  sleep 1
done

sleep 7

echo
echo "=== 4. window + DOM ==="
wid=$(xdotool search --name 'UMBRA Framework' 2>/dev/null | head -1)
if [[ -n "$wid" ]]; then
  xdotool windowactivate "$wid" 2>/dev/null || true
  xdotool windowsize "$wid" 985 730 2>/dev/null || true
  xdotool windowmove "$wid" 0 0 2>/dev/null || true
  echo "  window id=$wid"
fi

python3 /tmp/cdp.py evalfile /tmp/js-inspect.js 2>&1 | head -20

echo
echo "=== 5. disk ==="
df -h /tmp | tail -1
