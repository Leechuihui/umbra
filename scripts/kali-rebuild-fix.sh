#!/usr/bin/env bash
# Rebuild the client with the config.json permission fix.

set -uo pipefail

ROOT=/opt/umbra
GUI="$ROOT/client/gui"
LOG=/tmp/rebuild.log

echo "=== copying updated electron main ==="
if [[ -f /tmp/index-new.ts ]]; then
  echo "Lizhuhui" | sudo -S -p '' cp /tmp/index-new.ts "$GUI/electron/index.ts" 2>/dev/null \
    && echo "copied" || { echo "copy failed"; exit 1; }
else
  echo "missing /tmp/index-new.ts"
  exit 1
fi

echo
echo "=== rebuilding (npm run dist) ==="
echo "Lizhuhui" | sudo -S -p '' bash -c "cd '$GUI' && TMPDIR='$ROOT/.build-tmp' npm run dist" > "$LOG" 2>&1
rc=$?

echo "rebuild exit=$rc"
echo
echo "=== result ==="
ls -lh "$GUI/dist/umbra.AppImage" 2>/dev/null
tail -5 "$LOG" | sed 's/^/  /'

exit "$rc"
