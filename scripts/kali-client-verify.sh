#!/usr/bin/env bash
# Confirm the client starts cleanly and writes config to a writable location.

set -uo pipefail

export DISPLAY=:0
export XAUTHORITY=/home/myroot/.Xauthority

APP=/opt/umbra/client/gui/dist/umbra.AppImage
LOG=/tmp/client3.log

rm -f "$LOG"

# Make sure no stale instance is running.
pkill -f 'umbra' 2>/dev/null || true
sleep 1

echo "=== launching client (12s) ==="
( timeout 12 "$APP" --appimage-extract-and-run --no-sandbox > "$LOG" 2>&1 & )
sleep 9

echo
echo "=== process running? ==="
if pgrep -f 'appimage_extracted.*umbra' >/dev/null 2>&1 || pgrep -f 'dist/umbra' >/dev/null 2>&1; then
  echo "YES - client is running"
else
  echo "no client process"
fi

echo
echo "=== errors in log ==="
if grep -qiE 'error|eacces|denied|unhandled' "$LOG" 2>/dev/null; then
  grep -iE 'error|eacces|denied|unhandled' "$LOG" | head -8 | sed 's/^/  /'
else
  echo "  (none)"
fi

echo
echo "=== where did config.json go? ==="
find /home/myroot /root /opt/umbra -maxdepth 6 -name 'config.json' -newermt '-5 minutes' 2>/dev/null | head -5 \
  || echo "  (not found)"

echo
echo "=== userData dir ==="
ls -la /home/myroot/.config/ 2>/dev/null | grep -i umbra || echo "  no umbra dir in ~/.config"

echo
echo "=== full log (first 20) ==="
head -20 "$LOG" 2>/dev/null | sed 's/^/  /'

pkill -f 'umbra' 2>/dev/null || true
echo
echo "done"
