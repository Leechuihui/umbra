#!/usr/bin/env bash
# Move the project off tmpfs onto the real disk, then re-run the client build.
# /tmp is a 1.9G tmpfs on Kali; AppImage packaging needs more than that.
# NOTE: runs as the normal user, so privileged steps go through sudo.

set -uo pipefail

SRC=/tmp/umbra
DEST=/opt/umbra
LOG=/tmp/umbra-client.log

if [[ ! -d "$SRC" ]]; then
  echo "ERROR: $SRC missing"
  exit 1
fi

echo "=== moving $SRC -> $DEST (off tmpfs) ==="
echo "Lizhuhui" | sudo -S -p '' rm -rf "$DEST" 2>/dev/null
echo "Lizhuhui" | sudo -S -p '' mkdir -p "$DEST" 2>/dev/null || { echo "mkdir failed"; exit 1; }

echo "Lizhuhui" | sudo -S -p '' cp -a "$SRC"/. "$DEST"/ 2>/dev/null || { echo "copy failed"; exit 1; }

echo "copy done, freeing tmpfs..."
rm -rf "$SRC" 2>/dev/null || echo "Lizhuhui" | sudo -S -p '' rm -rf "$SRC"

echo
echo "=== disk after move ==="
df -h / | tail -1
df -h /tmp | tail -1

echo
echo "=== re-running client build ==="
echo "Lizhuhui" | sudo -S -p '' bash -c "cd '$DEST/client/gui' && npm run dist" > "$LOG" 2>&1
rc=$?

echo "client build exit=$rc"
echo
echo "=== last 25 lines ==="
tail -25 "$LOG"

echo
echo "=== dist contents ==="
ls -lh "$DEST/client/gui/dist" 2>/dev/null | head -10

exit "$rc"
