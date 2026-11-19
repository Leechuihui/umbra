#!/usr/bin/env bash
# Test whether server/requirements.txt installs cleanly on this Linux.
# Creates a throwaway venv so the real one is untouched.

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REQ="$ROOT/server/requirements.txt"
TMP="${TMPDIR:-/tmp}/umbra-pip-test"

[[ -f "$REQ" ]] || { echo "missing $REQ"; exit 1; }

rm -rf "$TMP"
python3 -m venv "$TMP" || { echo "venv creation failed"; exit 1; }
# shellcheck source=/dev/null
source "$TMP/bin/activate"

pip install --upgrade pip -q

echo "=== installing requirements (this may take a few minutes) ==="
if pip install -r "$REQ" 2>&1 | tee "$TMP/pip.log" | tail -30; then
  echo
  echo "RESULT: all requirements installed"
  rc=0
else
  echo
  echo "RESULT: install FAILED — failing packages:"
  grep -E '^ERROR:|Could not build wheels|Failed building wheel' "$TMP/pip.log" | head -20
  rc=1
fi

deactivate 2>/dev/null || true
rm -rf "$TMP"
exit "$rc"
