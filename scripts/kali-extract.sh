#!/usr/bin/env bash
# Extract the uploaded UMBRA source and probe the environment.

set -uo pipefail

TARBALL=/tmp/umbra-src.tar.gz
DEST=/tmp/umbra

if [[ ! -f "$TARBALL" ]]; then
  echo "ERROR: $TARBALL not found"
  exit 1
fi

echo "=== tarball ==="
ls -lh "$TARBALL"

echo
echo "=== extracting ==="
rm -rf "$DEST"
mkdir -p "$DEST"
tar -xzf "$TARBALL" -C "$DEST" || { echo "extract failed"; exit 1; }
echo "extracted to $DEST"

echo
echo "=== top level ==="
ls -la "$DEST" | head -20

echo
echo "=== scripts present ==="
for f in install.sh install/linux.sh umbra.py; do
  if [[ -f "$DEST/$f" ]]; then
    printf '%-20s ' "$f"
    if [[ -x "$DEST/$f" ]]; then echo "executable"; else echo "NOT executable"; fi
  else
    echo "MISSING: $f"
  fi
done

echo
echo "=== line endings ==="
for f in install.sh install/linux.sh umbra.py; do
  if [[ -f "$DEST/$f" ]]; then
    if grep -q $'\r' "$DEST/$f" 2>/dev/null; then
      echo "CRLF: $f"
    else
      echo "LF:   $f"
    fi
  fi
done

echo
echo "=== toolchain ==="
for t in git python3 node npm sqlite3 curl cargo go nim gcc make; do
  printf '%-8s ' "$t"
  if command -v "$t" >/dev/null 2>&1; then
    "$t" --version 2>&1 | head -1
  else
    echo MISSING
  fi
done

echo
echo "=== python venv support ==="
python3 -c 'import venv; print("venv OK")' 2>/dev/null || echo "venv MISSING"
