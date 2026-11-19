#!/usr/bin/env bash
# Real end-to-end install test on Kali.
# Runs the actual installer as root and captures all output.

set -uo pipefail

SRC=/tmp/umbra
LOG=/tmp/umbra-install.log

if [[ ! -d "$SRC" ]]; then
  echo "ERROR: $SRC missing"
  exit 1
fi

cd "$SRC" || exit 1

# Simulate a fresh git clone: git preserves +x, the tarball lost it.
chmod +x install.sh install/linux.sh install/mac.sh umbra.py \
         server/infra/bin/encoders/sgn/build.sh 2>/dev/null || true

echo "=== starting install (log: $LOG) ==="
echo "Lizhuhui" | sudo -S -p '' bash install.sh all > "$LOG" 2>&1
rc=$?

echo "=== install finished, exit=$rc ==="
echo
echo "=== last 40 lines of log ==="
tail -40 "$LOG"

echo
echo "=== errors/warnings in log ==="
grep -iE 'error|failed|cannot|not found|denied' "$LOG" | head -20 || echo "(none)"

exit "$rc"
