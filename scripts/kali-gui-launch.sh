#!/usr/bin/env bash
# Launch the UMBRA client on the Kali desktop and capture the screen.

set -uo pipefail

ROOT=/home/myroot/umbra
export DISPLAY=:0
export XAUTHORITY=/home/myroot/.Xauthority

echo "=== 1. stop any running client ==="
pkill -f 'appimage_extracted' 2>/dev/null && echo "  stopped extracted" || echo "  none extracted"
pkill -f 'dist/umbra.AppImage' 2>/dev/null && echo "  stopped AppImage" || echo "  none AppImage"
sleep 2

echo
echo "=== 2. launch client ==="
cd "$ROOT/client/gui/dist" || { echo "  no dist dir"; exit 1; }
setsid nohup ./umbra.AppImage --appimage-extract-and-run --no-sandbox \
  > /tmp/umbra-client.log 2>&1 < /dev/null &
echo "  launched, waiting for window..."

for i in $(seq 1 40); do
  if xdotool search --name "UMBRA" >/dev/null 2>&1; then
    echo "  window appeared after ${i}s"
    break
  fi
  sleep 1
done

sleep 4

echo
echo "=== 3. windows ==="
found=0
while IFS= read -r wid; do
  [[ -z "$wid" ]] && continue
  name=$(xdotool getwindowname "$wid" 2>/dev/null || echo "?")
  geo=$(xdotool getwindowgeometry "$wid" 2>/dev/null | tr '\n' ' ' || echo "?")
  echo "  id=$wid name='$name' $geo"
  found=1
done < <(xdotool search --name "UMBRA" 2>/dev/null)
[[ "$found" -eq 0 ]] && echo "  no UMBRA window found"

echo
echo "=== 4. screenshot ==="
if import -window root /tmp/shot1.png 2>/dev/null; then
  echo "  saved /tmp/shot1.png ($(du -h /tmp/shot1.png | cut -f1))"
else
  echo "  screenshot failed"
fi

echo
echo "=== 5. client log tail ==="
tail -6 /tmp/umbra-client.log 2>/dev/null | sed 's/^/  /' || echo "  no log"
