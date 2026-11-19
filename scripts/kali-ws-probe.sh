#!/usr/bin/env bash
# Probe for a WebSocket client usable to drive the DevTools protocol.

echo "=== python modules ==="
for m in websocket websockets aiohttp; do
  if python3 -c "import $m" 2>/dev/null; then
    echo "[OK] $m"
  else
    echo "[--] $m"
  fi
done

echo
echo "=== cli tools ==="
for t in websocat wscat; do
  if command -v "$t" >/dev/null 2>&1; then
    echo "[OK] $t"
  else
    echo "[--] $t"
  fi
done

echo
echo "=== node ==="
command -v node >/dev/null 2>&1 && node --version || echo "no node"

echo
echo "=== pip availability ==="
python3 -m pip --version 2>&1 | head -1 || echo "no pip"
