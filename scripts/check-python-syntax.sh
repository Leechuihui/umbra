#!/usr/bin/env bash
# Compile-check every Python file in the repo (server + entrypoint).
# Catches syntax errors that would abort startup on Linux.

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 required"
  exit 1
fi

echo "python: $(python3 --version 2>&1)"
echo

fail=0
ok=0

while IFS= read -r f; do
  if python3 -m py_compile "$f" 2>/tmp/pyerr; then
    ok=$((ok+1))
  else
    echo "  [FAIL] ${f#$ROOT/}"
    sed 's/^/         /' /tmp/pyerr | head -3
    fail=$((fail+1))
  fi
done < <(find "$ROOT/server" "$ROOT/implants" -name '*.py' -type f 2>/dev/null; echo "$ROOT/umbra.py")

echo "compiled ok: $ok"
echo "failed:      $fail"

# clean __pycache__ created by py_compile
find "$ROOT/server" "$ROOT/implants" -name '__pycache__' -type d -exec rm -rf {} + 2>/dev/null || true

[[ "$fail" -eq 0 ]] && exit 0 || exit 1
