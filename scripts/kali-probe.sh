#!/usr/bin/env bash
# Environment probe for the Kali install test.

echo "=== OS ==="
head -3 /etc/os-release
echo
echo "=== DISK ==="
df -h / | tail -1
echo
echo "=== MEM ==="
free -h | head -2
echo
echo "=== TOOLCHAIN ==="
for t in git python3 node npm sqlite3 curl cargo go nim gcc make; do
  printf '%-8s ' "$t"
  if command -v "$t" >/dev/null 2>&1; then
    "$t" --version 2>&1 | head -1
  else
    echo MISSING
  fi
done
echo
echo "=== PYTHON VERSION ==="
python3 -c 'import sys; print("%d.%d.%d" % sys.version_info[:3])' 2>/dev/null || echo "no python3"
echo
echo "=== VENV SUPPORT ==="
python3 -c 'import venv; print("venv OK")' 2>/dev/null || echo "venv MISSING"
echo
echo "=== SHARED FOLDER ==="
ls -la /media/sf_* 2>/dev/null || echo "no shared folder mounted"
