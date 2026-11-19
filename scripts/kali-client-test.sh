#!/usr/bin/env bash
# Verify the UMBRA client can start on the Kali desktop.

set -uo pipefail

APP=/opt/umbra/client/gui/dist/umbra.AppImage

echo "=== AppImage ==="
ls -lh "$APP" 2>/dev/null || { echo "missing"; exit 1; }

echo
echo "=== launching on DISPLAY=:0 (10s) ==="
export DISPLAY=:0
export XAUTHORITY=/home/myroot/.Xauthority

# Kali has no libfuse2, so extract-and-run is required.
( timeout 10 "$APP" --appimage-extract-and-run --no-sandbox > /tmp/client-run.log 2>&1 & )
sleep 8

echo "=== process check ==="
if pgrep -f 'umbra' > /dev/null 2>&1; then
  echo "client process RUNNING"
  pgrep -af 'umbra' | head -3
else
  echo "client process not found"
fi

echo
echo "=== windows on :0 ==="
if command -v wmctrl >/dev/null 2>&1; then
  wmctrl -l 2>/dev/null | head -5 || echo "(wmctrl no output)"
else
  echo "(wmctrl not installed)"
fi

echo
echo "=== client log ==="
tail -15 /tmp/client-run.log 2>/dev/null | sed 's/^/  /'

pkill -f 'umbra' 2>/dev/null || true
echo
echo "done"
