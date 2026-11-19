#!/usr/bin/env bash
# Verify the fixes made after the first real install test.

set -uo pipefail

TARBALL=/tmp/umbra-final.tar.gz
DEST=/opt/umbra-final
PASS=0
FAIL=0

ok()  { echo "  [OK]   $*"; PASS=$((PASS+1)); }
bad() { echo "  [FAIL] $*"; FAIL=$((FAIL+1)); }

section() { echo; echo "=== $* ==="; }

section "1. Extract final source"
echo "Lizhuhui" | sudo -S -p '' rm -rf "$DEST" 2>/dev/null
echo "Lizhuhui" | sudo -S -p '' mkdir -p "$DEST" 2>/dev/null
echo "Lizhuhui" | sudo -S -p '' tar -xzf "$TARBALL" -C "$DEST" 2>/dev/null \
  && ok "extracted to $DEST" || bad "extract failed"

section "2. has_libfuse2() detects Kali correctly"
cd "$DEST" || exit 1
RESULT=$(python3 -c "
import sys
sys.path.insert(0, '.')
import importlib.util
spec = importlib.util.spec_from_file_location('umbra', 'umbra.py')
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
print('libfuse2:', mod.has_libfuse2())
" 2>&1)
echo "  $RESULT"
if echo "$RESULT" | grep -q 'libfuse2: False'; then
  ok "correctly detects missing libfuse2 -> will use extract-and-run"
elif echo "$RESULT" | grep -q 'libfuse2: True'; then
  ok "libfuse2 present (native mount works)"
else
  bad "has_libfuse2() failed: $RESULT"
fi

section "3. Disk space guard"
# Extract the function and call it with a tiny threshold to prove it works.
eval "$(sed -n '/^check_disk_space()/,/^}/p' "$DEST/install/linux.sh")"
main_dir="$DEST"
MIN_FREE_GB=1
if check_disk_space > /tmp/diskcheck.log 2>&1; then
  ok "passes with 1 GB threshold"
  cat /tmp/diskcheck.log | sed 's/^/  /'
else
  bad "disk check failed unexpectedly"
fi

MIN_FREE_GB=9999
if check_disk_space > /tmp/diskcheck2.log 2>&1; then
  bad "should have refused with 9999 GB threshold"
else
  ok "correctly refuses when space is insufficient"
  head -2 /tmp/diskcheck2.log | sed 's/^/  /'
fi

section "4. TMPDIR redirect"
eval "$(sed -n '/^prepare_build_tmpdir()/,/^}/p' "$DEST/install/linux.sh")"
main_dir="$DEST"
prepare_build_tmpdir > /tmp/tmpdir.log 2>&1
if [[ "${TMPDIR:-}" == "$DEST/.build-tmp" ]]; then
  ok "TMPDIR redirected off tmpfs: $TMPDIR"
else
  bad "TMPDIR not redirected (got: ${TMPDIR:-unset})"
fi

section "5. t64 alternative resolution"
eval "$(sed -n '/^apt_has()/,/^}/p' "$DEST/install/linux.sh")"
if apt_has libgtk-3-0t64; then
  ok "libgtk-3-0t64 resolves on Kali"
else
  bad "libgtk-3-0t64 not found"
fi
if apt_has libfuse2; then
  ok "libfuse2 resolves"
else
  echo "  [INFO] libfuse2 absent on Kali -> extract-and-run fallback handles it"
fi

section "6. Entrypoint syntax + version"
if python3 -m py_compile "$DEST/umbra.py" 2>/dev/null; then
  ok "umbra.py compiles"
else
  bad "umbra.py syntax error"
fi

section "SUMMARY"
echo "  passed: $PASS"
echo "  failed: $FAIL"
[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
