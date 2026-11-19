#!/usr/bin/env bash
# Verify every package name referenced by install/linux.sh actually exists
# in the current distro's apt repositories.

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LINUX_SH="$ROOT/install/linux.sh"

if ! command -v apt-cache >/dev/null 2>&1; then
  echo "apt-cache not available; this check is for Debian/Ubuntu only."
  exit 0
fi

apt_has() {
  local candidate
  candidate="$(apt-cache policy "$1" 2>/dev/null | awk '/Candidate:/ {print $2}')"
  [[ -n "$candidate" && "$candidate" != "(none)" ]]
}

# --- required packages (any miss is fatal) ---
mapfile -t required < <(
  sed -n '/^apt_required=(/,/^)/p' "$LINUX_SH" \
    | grep -vE '^\(|\)$|^apt_required=|^\s*#' \
    | tr -d ' ' | grep -v '^$'
)

# --- optional packages (miss only warns) ---
mapfile -t optional < <(
  sed -n '/^apt_optional=(/,/^)/p' "$LINUX_SH" \
    | grep -vE '^\(|\)$|^apt_optional=|^\s*#' \
    | tr -d ' ' | grep -v '^$'
)

# --- t64 alternatives (need at least one of each pair) ---
mapfile -t alternatives < <(
  sed -n '/^apt_alternatives=(/,/^)/p' "$LINUX_SH" \
    | grep -vE '^\(|\)$|^apt_alternatives=|^\s*#' \
    | tr -d '"' | sed 's/^[[:space:]]*//' | grep -v '^$'
)

fail=0
warn=0

section() { echo; echo "=== $* ==="; }

section "REQUIRED (fatal if missing)"
for p in "${required[@]}"; do
  if apt_has "$p"; then
    echo "  [OK]      $p"
  else
    echo "  [FATAL]   $p  <-- not in repo"
    fail=$((fail+1))
  fi
done

section "T64 ALTERNATIVES (need at least one)"
for entry in "${alternatives[@]}"; do
  read -r new_name legacy_name <<< "$entry"
  if apt_has "$new_name"; then
    echo "  [OK]      $new_name"
  elif apt_has "$legacy_name"; then
    echo "  [OK]      $legacy_name (legacy fallback)"
  else
    echo "  [WARN]    neither $new_name nor $legacy_name"
    warn=$((warn+1))
  fi
done

section "OPTIONAL (warn only)"
for p in "${optional[@]}"; do
  if apt_has "$p"; then
    echo "  [OK]      $p"
  else
    echo "  [WARN]    $p"
    warn=$((warn+1))
  fi
done

section "SUMMARY"
echo "  fatal:  $fail"
echo "  warn:   $warn"
if [[ "$fail" -eq 0 ]]; then
  echo "  RESULT: all required packages resolvable"
  exit 0
fi
echo "  RESULT: $fail required package(s) missing"
exit 1
