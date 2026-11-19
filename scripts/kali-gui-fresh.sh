#!/usr/bin/env bash
# Restart the UMBRA client with DevTools enabled and report the fresh DOM state.

set -uo pipefail

ROOT=/home/myroot/umbra
export DISPLAY=:0
export XAUTHORITY=/home/myroot/.Xauthority

echo "=== 1. stop client ==="
pkill -f 'appimage_extracted' 2>/dev/null && echo "  stopped extracted" || echo "  none"
pkill -f 'dist/umbra.AppImage' 2>/dev/null && echo "  stopped AppImage" || echo "  none"
sleep 3

echo
echo "=== 2. ensure server is up ==="
if ! ss -ltn 2>/dev/null | grep -q ':9000'; then
  echo "  starting server..."
  cd "$ROOT" || exit 1
  setsid nohup ./umbra.py server start > /tmp/umbra-server.log 2>&1 < /dev/null &
  for i in $(seq 1 30); do
    ss -ltn 2>/dev/null | grep -q ':9000' && break
    sleep 1
  done
fi
ss -ltn 2>/dev/null | grep -q ':9000' && echo "  server listening" || echo "  SERVER DOWN"

echo
echo "=== 3. relaunch client with DevTools ==="
cd "$ROOT/client/gui/dist" || exit 1
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
echo "=== 4. fresh DOM state ==="
python3 /tmp/cdp.py evalfile /tmp/js-inspect.js 2>&1

echo
echo "=== 5. screenshot ==="
import -window root /tmp/gui-fresh.png 2>/dev/null && echo "  saved /tmp/gui-fresh.png" || echo "  failed"
