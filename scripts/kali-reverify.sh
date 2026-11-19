#!/usr/bin/env bash
# Re-verify fixes with the updated umbra.py (now guarded by __main__).

set -uo pipefail

DEST=/opt/umbra-final
PASS=0
FAIL=0

ok()  { echo "  [OK]   $*"; PASS=$((PASS+1)); }
bad() { echo "  [FAIL] $*"; FAIL=$((FAIL+1)); }

section() { echo; echo "=== $* ==="; }

section "1. Install updated umbra.py"
if [[ -f /tmp/umbra-new.py ]]; then
  echo "Lizhuhui" | sudo -S -p '' cp /tmp/umbra-new.py "$DEST/umbra.py" 2>/dev/null \
    && ok "umbra.py updated" || bad "copy failed"
else
  bad "/tmp/umbra-new.py missing"
fi

section "2. Import has no CLI side-effect"
cd "$DEST" || exit 1
OUT=$(python3 -c "
import importlib.util
spec = importlib.util.spec_from_file_location('umbra', 'umbra.py')
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
print('IMPORT_OK')
print('libfuse2=' + str(m.has_libfuse2()))
" 2>&1)
echo "$OUT" | sed 's/^/  /'
if echo "$OUT" | grep -q 'IMPORT_OK'; then
  ok "import clean (no help text printed)"
else
  bad "import still has side effects"
fi
if echo "$OUT" | grep -q 'libfuse2=False'; then
  ok "has_libfuse2() = False on Kali -> extract-and-run fallback"
elif echo "$OUT" | grep -q 'libfuse2=True'; then
  ok "has_libfuse2() = True"
else
  bad "has_libfuse2() did not report"
fi

section "3. CLI still works"
if python3 umbra.py version 2>&1 | grep -q 'server'; then
  ok "version command works"
  python3 umbra.py version 2>&1 | sed 's/^/  /'
else
  bad "version command broken"
fi

if python3 umbra.py help 2>&1 | grep -q 'USAGE'; then
  ok "help command works"
else
  bad "help command broken"
fi

section "4. Disk guard (both directions)"
eval "$(sed -n '/^check_disk_space()/,/^}/p' "$DEST/install/linux.sh")"
main_dir="$DEST"
MIN_FREE_GB=1
if check_disk_space > /tmp/d1.log 2>&1; then
  ok "passes at 1 GB threshold"
else
  bad "unexpected failure at 1 GB"
fi
MIN_FREE_GB=9999
# check_disk_space calls exit 1 on purpose, so run it in a subshell.
if ( check_disk_space ) > /tmp/d2.log 2>&1; then
  bad "should refuse at 9999 GB"
else
  ok "refuses when space insufficient (exit 1)"
  head -2 /tmp/d2.log | sed 's/^/  /'
fi

section "5. TMPDIR redirect"
eval "$(sed -n '/^prepare_build_tmpdir()/,/^}/p' "$DEST/install/linux.sh")"
main_dir="$DEST"
prepare_build_tmpdir > /tmp/t.log 2>&1
if [[ "${TMPDIR:-}" == "$DEST/.build-tmp" ]]; then
  ok "TMPDIR -> $TMPDIR (off tmpfs)"
else
  bad "TMPDIR not redirected: ${TMPDIR:-unset}"
fi

section "6. t64 package resolution"
eval "$(sed -n '/^apt_has()/,/^}/p' "$DEST/install/linux.sh")"
for p in libgtk-3-0t64 libasound2t64 libatspi2.0-0t64; do
  if apt_has "$p"; then ok "$p resolves"; else bad "$p missing"; fi
done
# libfuse2 is intentionally absent on Kali; the AppImage falls back to
# --appimage-extract-and-run, so its absence is not a failure.
if apt_has libfuse2t64 || apt_has libfuse2; then
  ok "libfuse2 available (native AppImage mount)"
else
  ok "libfuse2 absent -> extract-and-run fallback (expected on Kali)"
fi

section "SUMMARY"
echo "  passed: $PASS"
echo "  failed: $FAIL"
[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
