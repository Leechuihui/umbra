#!/usr/bin/env bash
# Report the current UMBRA install state on Kali.

echo "=== OS ==="
head -2 /etc/os-release

echo
echo "=== toolchain ==="
for t in git python3 node npm sqlite3 curl cargo go nim gcc; do
  printf '%-8s ' "$t"
  if command -v "$t" >/dev/null 2>&1; then
    "$t" --version 2>&1 | head -1
  else
    echo "MISSING"
  fi
done

echo
echo "=== install dirs ==="
for d in /opt/umbra /opt/umbra-final /root/umbra; do
  if [[ -d "$d" ]]; then
    echo "$d  ($(du -sh "$d" 2>/dev/null | cut -f1))"
  fi
done

echo
echo "=== listening ports ==="
ss -ltn 2>/dev/null | grep -E ':9000|:8080' || echo "none"

echo
echo "=== artifacts in /opt/umbra ==="
ls -lh /opt/umbra/client/gui/dist/umbra.AppImage 2>/dev/null || echo "no AppImage"
ls -d /opt/umbra/server/venv 2>/dev/null || echo "no venv"
ls -lh /opt/umbra/server/infra/bin/encoders/sgn/sgn 2>/dev/null || echo "no sgn"
ls -lh /opt/umbra/server/infra/database/database.db 2>/dev/null || echo "no database"

echo
echo "=== operator keys ==="
ls -lh /opt/umbra/*.key 2>/dev/null || echo "no key files"

echo
echo "=== desktop entry ==="
find /home /root -name 'com.umbra.app.desktop' 2>/dev/null | head -2 || echo "none"

echo
echo "=== client config ==="
for f in /home/myroot/.config/umbra/config.json /root/.config/umbra/config.json; do
  if [[ -f "$f" ]]; then
    echo "$f:"
    cat "$f"
  fi
done

echo
echo "=== running umbra processes ==="
pgrep -af 'umbra|appimage_extracted' 2>/dev/null | head -5 || echo "none"
