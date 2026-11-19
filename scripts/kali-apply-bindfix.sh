#!/usr/bin/env bash
# Apply the listener bind-address fix on Kali and rebuild the client.
#
# The fix adds a dedicated bindHost field so selecting a team server no longer
# writes its IP into the listener's bind address.

set -uo pipefail

ROOT=/home/myroot/umbra
GUI="$ROOT/client/gui"
LOG=/tmp/rebuild-bindfix.log

echo "=== 1. stop the client ==="
pkill -f 'appimage_extracted' 2>/dev/null && echo "  stopped" || echo "  none"
pkill -f 'dist/umbra.AppImage' 2>/dev/null || true
sleep 3

echo
echo "=== 2. install the patched sources ==="
for pair in \
  "/tmp/patch-logic.tsx:$GUI/src/components/canva/topbar/listeners/components/logic.tsx" \
  "/tmp/patch-listeners.tsx:$GUI/src/api/listeners.tsx"
do
  src="${pair%%:*}"
  dst="${pair#*:}"
  if [[ -f "$src" ]]; then
    cp "$src" "$dst" && echo "  installed $(basename "$dst")" || echo "  FAILED $dst"
  else
    echo "  missing $src"
  fi
done

echo
echo "=== 3. confirm the patch is present ==="
if grep -q "bindHost" "$GUI/src/components/canva/topbar/listeners/components/logic.tsx"; then
  echo "  logic.tsx has bindHost"
else
  echo "  logic.tsx MISSING bindHost"
fi
if grep -q "bindAddress" "$GUI/src/api/listeners.tsx"; then
  echo "  listeners.tsx has bindAddress"
else
  echo "  listeners.tsx MISSING bindAddress"
fi

echo
echo "=== 4. rebuild (this takes a few minutes) ==="
mkdir -p "$ROOT/.build-tmp"
cd "$GUI" || exit 1
TMPDIR="$ROOT/.build-tmp" npm run dist > "$LOG" 2>&1
rc=$?
echo "  rebuild exit=$rc"

if [[ "$rc" -ne 0 ]]; then
  echo "  --- last 25 log lines ---"
  tail -25 "$LOG" | sed 's/^/    /'
  exit 1
fi

echo
echo "=== 5. artifact ==="
ls -lh "$GUI/dist/umbra.AppImage" 2>/dev/null | sed 's/^/  /'

echo
echo "=== 6. relaunch with DevTools ==="
export DISPLAY=:0
export XAUTHORITY=/home/myroot/.Xauthority
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

sleep 6
echo "  client relaunched"
