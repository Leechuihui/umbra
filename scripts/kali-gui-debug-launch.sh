#!/usr/bin/env bash
# Relaunch the UMBRA client with the DevTools protocol enabled so the GUI can
# be driven and inspected programmatically instead of by blind clicking.

set -uo pipefail

ROOT=/home/myroot/umbra
export DISPLAY=:0
export XAUTHORITY=/home/myroot/.Xauthority

echo "=== 1. stop the running client ==="
pkill -f 'appimage_extracted' 2>/dev/null && echo "  stopped" || echo "  not running"
pkill -f 'dist/umbra.AppImage' 2>/dev/null || true
sleep 3

echo
echo "=== 2. relaunch with --remote-debugging-port=9222 ==="
cd "$ROOT/client/gui/dist" || { echo "  no dist dir"; exit 1; }
setsid nohup ./umbra.AppImage \
  --appimage-extract-and-run \
  --no-sandbox \
  --remote-debugging-port=9222 \
  --remote-allow-origins='*' \
  > /tmp/umbra-client.log 2>&1 < /dev/null &

echo "  waiting for the debug port..."
for i in $(seq 1 40); do
  if curl -s --max-time 2 http://127.0.0.1:9222/json/version >/dev/null 2>&1; then
    echo "  debug port up after ${i}s"
    break
  fi
  sleep 1
done

echo
echo "=== 3. DevTools version ==="
curl -s --max-time 3 http://127.0.0.1:9222/json/version 2>/dev/null | head -c 300
echo

echo
echo "=== 4. targets ==="
curl -s --max-time 3 http://127.0.0.1:9222/json 2>/dev/null \
  | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    print("  could not parse targets")
    sys.exit(0)
for t in d:
    print(f"  type={t.get(\"type\")}  title={t.get(\"title\")!r}  url={t.get(\"url\")[:60]!r}")
' 2>/dev/null || echo "  no targets"

echo
echo "=== 5. window geometry ==="
wid=$(xdotool search --name 'UMBRA Framework' 2>/dev/null | head -1)
if [[ -n "$wid" ]]; then
  xdotool windowactivate "$wid" 2>/dev/null || true
  xdotool windowsize "$wid" 985 730 2>/dev/null || true
  xdotool windowmove "$wid" 0 0 2>/dev/null || true
  sleep 1
  echo "  window id=$wid"
  xdotool getwindowgeometry --shell "$wid" 2>/dev/null | sed 's/^/    /'
else
  echo "  UMBRA window not found"
fi

echo
echo "=== 6. screenshot ==="
import -window root /tmp/umbra-debug.png 2>/dev/null \
  && echo "  saved /tmp/umbra-debug.png" || echo "  failed"
