#!/usr/bin/env bash
# Probe GUI automation readiness on the Kali desktop.

echo "=== display / session ==="
echo "DISPLAY=${DISPLAY:-unset}"
pgrep -a Xorg 2>/dev/null | head -1 || echo "no Xorg"
loginctl list-sessions --no-legend 2>/dev/null | head -3

echo
echo "=== GUI automation tools ==="
for t in xdotool wmctrl xwininfo import scrot; do
  if command -v "$t" >/dev/null 2>&1; then
    echo "[OK] $t"
  else
    echo "[--] $t"
  fi
done

echo
echo "=== umbra processes ==="
pgrep -af 'server/main.py' 2>/dev/null | head -3 || echo "server: not running"
pgrep -af 'appimage_extracted|dist/umbra' 2>/dev/null | head -3 || echo "client: not running"

echo
echo "=== ports ==="
ss -ltn 2>/dev/null | grep -E ':9000|:8080' || echo "none"

echo
echo "=== client config ==="
cat /home/myroot/.config/umbra/config.json 2>/dev/null || echo "no config"

echo
echo "=== operator key ==="
head -1 /opt/umbra/admin.key 2>/dev/null | cut -c1-40 || echo "no key"
