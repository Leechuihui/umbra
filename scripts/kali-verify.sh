#!/usr/bin/env bash
# Post-install verification: server start, client binary, desktop entry.

set -uo pipefail

ROOT=/opt/umbra

echo "=== install artifacts ==="
ls -lh "$ROOT/client/gui/dist/umbra.AppImage" 2>/dev/null || echo "no AppImage"
ls -d "$ROOT/server/venv" 2>/dev/null || echo "no venv"
ls -lh "$ROOT/server/infra/bin/encoders/sgn/sgn" 2>/dev/null || echo "no sgn"
ls -lh "$ROOT/server/infra/database/database.db" 2>/dev/null || echo "no database"

echo
echo "=== desktop entry ==="
find /home /root -name 'com.umbra.app.desktop' 2>/dev/null | head -3

echo
echo "=== icons installed ==="
find /home /root -path '*icons/hicolor*com.umbra.app.png' 2>/dev/null | head -5

echo
echo "=== server version ==="
cd "$ROOT" && ./umbra.py version 2>&1 | head -5

echo
echo "=== operator key creation ==="
cd "$ROOT" && ./umbra.py server key add admin 2>&1 | tail -5

echo
echo "=== server start (5s smoke test) ==="
cd "$ROOT" && timeout 5 ./umbra.py server start 2>&1 | head -20 || true

echo
echo "=== AppImage fuse check ==="
if ldd "$ROOT/client/gui/dist/umbra.AppImage" 2>/dev/null | grep -q 'not found'; then
  echo "missing libs:"
  ldd "$ROOT/client/gui/dist/umbra.AppImage" 2>/dev/null | grep 'not found'
else
  echo "no missing libs (or not an ELF)"
fi
