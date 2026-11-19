#!/usr/bin/env bash
# Progress monitor for the UMBRA install test.

LOG=/tmp/umbra-install.log

echo "=== log lines ==="
wc -l "$LOG" 2>/dev/null || echo "no log"

echo
echo "=== last 10 lines ==="
tail -10 "$LOG" 2>/dev/null

echo
echo "=== active build processes ==="
ps -eo comm,args --no-headers 2>/dev/null \
  | grep -E '^(apt|dpkg|npm|node|pip|cargo|rustc|go|nim)' \
  | grep -v grep \
  | head -8 \
  || echo "(none)"

echo
echo "=== installed markers ==="
for t in node npm cargo go nim; do
  printf '%-8s ' "$t"
  command -v "$t" >/dev/null 2>&1 && echo "installed" || echo "-"
done

echo
echo "=== venv / dist ==="
[[ -d /tmp/umbra/server/venv ]] && echo "server/venv: exists" || echo "server/venv: -"
[[ -d /tmp/umbra/client/gui/node_modules ]] && echo "node_modules: exists" || echo "node_modules: -"
[[ -d /tmp/umbra/client/gui/dist ]] && echo "client dist: exists" || echo "client dist: -"
