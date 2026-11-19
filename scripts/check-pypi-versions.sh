#!/usr/bin/env bash
# Verify every pinned version in server/requirements.txt exists on PyPI.
# Catches typos / nonexistent versions that would abort the install.

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REQ="$ROOT/server/requirements.txt"

[[ -f "$REQ" ]] || { echo "missing $REQ"; exit 1; }

if ! command -v curl >/dev/null 2>&1; then
  echo "curl required"
  exit 1
fi

fail=0
ok=0

# Ensure the final line is processed even without a trailing newline.
while IFS= read -r line || [[ -n "$line" ]]; do
  # strip comments / blanks
  line="${line%%#*}"
  line="$(echo "$line" | tr -d '[:space:]')"
  [[ -z "$line" ]] && continue

  # handle extras like uvicorn[standard]==0.38.0
  pkg="${line%%==*}"
  ver="${line##*==}"
  pkg="${pkg%%[*}"

  if [[ "$pkg" == "$line" ]]; then
    echo "  [SKIP]    $line (no pin)"
    continue
  fi

  json="$(curl -fsSL "https://pypi.org/pypi/${pkg}/json" 2>/dev/null)"
  if [[ -z "$json" ]]; then
    echo "  [MISSING] $pkg (not on PyPI)"
    fail=$((fail+1))
    continue
  fi

  if echo "$json" | grep -q "\"${ver}\""; then
    echo "  [OK]      $pkg==$ver"
    ok=$((ok+1))
  else
    echo "  [BAD VER] $pkg==$ver  <-- version not found"
    fail=$((fail+1))
  fi
done < "$REQ"

echo
echo "ok: $ok   problems: $fail"
[[ "$fail" -eq 0 ]] && exit 0 || exit 1
