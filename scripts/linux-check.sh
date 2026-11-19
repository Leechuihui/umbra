#!/usr/bin/env bash
# Linux compatibility audit for UMBRA.
# Run from WSL/Linux: bash scripts/linux-check.sh

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
pass=0
fail=0
warn=0

ok()   { echo "  [OK]   $*"; pass=$((pass+1)); }
bad()  { echo "  [FAIL] $*"; fail=$((fail+1)); }
note() { echo "  [WARN] $*"; warn=$((warn+1)); }

section() { echo; echo "=== $* ==="; }

section "1. Line endings (CRLF breaks shebangs)"
for f in install.sh install/linux.sh install/mac.sh umbra.py \
         server/infra/bin/encoders/sgn/build.sh; do
  p="$ROOT/$f"
  [[ -f "$p" ]] || { bad "missing: $f"; continue; }
  if grep -q $'\r' "$p" 2>/dev/null; then
    bad "CRLF in $f"
  else
    ok "LF: $f"
  fi
done

section "2. Executable bits"
for f in install.sh install/linux.sh install/mac.sh umbra.py \
         server/infra/bin/encoders/sgn/build.sh; do
  p="$ROOT/$f"
  [[ -f "$p" ]] || continue
  if [[ -x "$p" ]]; then
    ok "executable: $f"
  else
    note "not executable (git mode may still be 100755): $f"
  fi
done

section "3. Bash syntax"
for f in install.sh install/linux.sh install/mac.sh \
         server/infra/bin/encoders/sgn/build.sh; do
  p="$ROOT/$f"
  [[ -f "$p" ]] || continue
  if bash -n "$p" 2>/dev/null; then
    ok "syntax: $f"
  else
    bad "syntax error: $f"
    bash -n "$p" 2>&1 | head -3 | sed 's/^/         /'
  fi
done

section "4. Python syntax"
if command -v python3 >/dev/null 2>&1; then
  ok "python3: $(python3 --version 2>&1)"
  if python3 -m py_compile "$ROOT/umbra.py" 2>/dev/null; then
    ok "syntax: umbra.py"
  else
    bad "syntax error: umbra.py"
  fi
else
  bad "python3 not installed"
fi

section "5. Required files"
for f in server/main.py server/requirements.txt \
         server/infra/database/init.sql \
         server/infra/bin/encoders/sgn/Cargo.toml \
         client/gui/package.json client/gui/electron/index.ts; do
  [[ -f "$ROOT/$f" ]] && ok "$f" || bad "missing: $f"
 done

section "6. Toolchain"
for t in python3 node npm sqlite3 cargo go nim gcc make curl; do
  if command -v "$t" >/dev/null 2>&1; then
    ok "$t"
  else
    note "$t not installed (installer will try)"
  fi
done

section "7. Node version (needs 20+)"
if command -v node >/dev/null 2>&1; then
  major="$(node -v | sed 's/^v\([0-9]*\).*/\1/')"
  if [[ "$major" -ge 20 ]]; then
    ok "node $(node -v)"
  else
    bad "node $(node -v) is too old (need 20+)"
  fi
else
  note "node not installed"
fi

section "8. Python version (needs 3.10+)"
if command -v python3 >/dev/null 2>&1; then
  if python3 -c 'import sys; raise SystemExit(0 if sys.version_info >= (3,10) else 1)'; then
    ok "$(python3 --version)"
  else
    bad "$(python3 --version) too old (need 3.10+)"
  fi
fi

section "9. Icons present"
for s in 16 32 48 128 256; do
  f="$ROOT/client/gui/public/icon_${s}x${s}.png"
  [[ -f "$f" ]] && ok "icon_${s}x${s}.png" || note "missing icon_${s}x${s}.png"
done

section "10. i18n dictionaries"
for f in client/gui/src/i18n/en.ts client/gui/src/i18n/zh.ts \
         client/gui/src/i18n/panels/registry.ts; do
  [[ -f "$ROOT/$f" ]] && ok "$f" || bad "missing: $f"
done

section "11. No stale nukerat references"
stale=$(grep -rIl --exclude-dir=node_modules --exclude-dir=.git \
        -E 'nukeratframework/(nukerat|umbra)' "$ROOT" 2>/dev/null \
        | grep -v 'armory' | head -5 || true)
if [[ -z "$stale" ]]; then
  ok "no stale references (armory upstream allowed)"
else
  note "references found in:"
  echo "$stale" | sed 's/^/         /'
fi

section "SUMMARY"
echo "  passed:  $pass"
echo "  warnings:$warn"
echo "  failed:  $fail"
echo
if [[ "$fail" -eq 0 ]]; then
  echo "  RESULT: ready for Linux install"
  exit 0
else
  echo "  RESULT: $fail blocking issue(s) found"
  exit 1
fi
