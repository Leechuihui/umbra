#!/usr/bin/env bash
# Clean up the Kali install: duplicate servers, stale dirs, duplicate keys.
# Keeps /opt/umbra (the complete install) and removes everything else.

set -uo pipefail

echo "=== 1. stop all running umbra processes ==="
pkill -f 'server/main.py' 2>/dev/null && echo "  stopped server" || echo "  no server running"
pkill -f 'appimage_extracted' 2>/dev/null && echo "  stopped client" || echo "  no client running"
pkill -f 'dist/umbra.AppImage' 2>/dev/null || true
sleep 2

echo
echo "=== 2. remove stale install dir ==="
if [[ -d /opt/umbra-final ]]; then
  echo "Lizhuhui" | sudo -S -p '' rm -rf /opt/umbra-final 2>/dev/null && echo "  removed /opt/umbra-final" || echo "  failed to remove"
else
  echo "  /opt/umbra-final not present"
fi

echo
echo "=== 3. remove duplicate key file ==="
if [[ -f "/opt/umbra/admin(1).key" ]]; then
  rm -f "/opt/umbra/admin(1).key" && echo "  removed admin(1).key" || echo "  failed"
else
  echo "  no duplicate key"
fi

echo
echo "=== 4. verify remaining state ==="
echo "install dirs:"
for d in /opt/umbra /opt/umbra-final; do
  [[ -d "$d" ]] && echo "  $d ($(du -sh "$d" 2>/dev/null | cut -f1))"
done

echo "key files:"
ls -1 /opt/umbra/*.key 2>/dev/null | sed 's/^/  /' || echo "  none"

echo "ports:"
ss -ltn 2>/dev/null | grep -E ':9000|:8080' | sed 's/^/  /' || echo "  none listening"

echo "processes:"
pgrep -af 'server/main.py|appimage_extracted' 2>/dev/null | sed 's/^/  /' || echo "  none running"

echo
echo "=== 5. disk ==="
df -h / | tail -1
