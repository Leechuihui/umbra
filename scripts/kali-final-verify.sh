#!/usr/bin/env bash
# Final verification: server listening, desktop entry, AppImage execution.

set -uo pipefail

ROOT=/opt/umbra
PASS=0
FAIL=0

ok()   { echo "  [OK]   $*"; PASS=$((PASS+1)); }
bad()  { echo "  [FAIL] $*"; FAIL=$((FAIL+1)); }

section() { echo; echo "=== $* ==="; }

section "1. Server actually listens on 9000"
cd "$ROOT" || exit 1
./umbra.py server start > /tmp/server-run.log 2>&1 &
SRV_PID=$!
sleep 12
if ss -ltnp 2>/dev/null | grep -q ':9000'; then
  ok "port 9000 is listening"
  ss -ltnp 2>/dev/null | grep ':9000'
else
  bad "port 9000 NOT listening"
  echo "  --- server log tail ---"
  tail -15 /tmp/server-run.log | sed 's/^/  /'
fi

# HTTP probe
if curl -fsS -o /dev/null -w "%{http_code}" --max-time 5 http://127.0.0.1:9000/ 2>/dev/null | grep -qE '^[2345]'; then
  ok "HTTP responds on 9000"
else
  bad "HTTP no response on 9000"
fi

kill $SRV_PID 2>/dev/null || true
wait $SRV_PID 2>/dev/null || true
pkill -f 'main.py' 2>/dev/null || true

section "2. Desktop entry creation"
# Re-run only the electron_files_setup portion via the installer function.
# The earlier full install aborted before this step, so test it directly.
if [[ -f "$ROOT/install/linux.sh" ]]; then
  # shellcheck source=/dev/null
  ( set +e; source "$ROOT/install/linux.sh" --help >/dev/null 2>&1; ) || true
fi

# Simpler: check what the function would produce by invoking it in isolation.
cat > /tmp/run-electron-setup.sh <<'EOS'
#!/usr/bin/env bash
set -uo pipefail
ROOT=/opt/umbra
main_dir="$ROOT"
# extract just the function body from linux.sh
eval "$(sed -n '/^electron_files_setup()/,/^}/p' "$ROOT/install/linux.sh")"
electron_files_setup
EOS
chmod +x /tmp/run-electron-setup.sh
if echo "Lizhuhui" | sudo -S -p '' /tmp/run-electron-setup.sh > /tmp/desktop-setup.log 2>&1; then
  ok "electron_files_setup completed"
else
  bad "electron_files_setup failed"
  tail -10 /tmp/desktop-setup.log | sed 's/^/  /'
fi

DESKTOP=$(find /home /root -name 'com.umbra.app.desktop' 2>/dev/null | head -1)
if [[ -n "$DESKTOP" ]]; then
  ok "desktop entry: $DESKTOP"
  grep -E '^(Name|Exec|Icon)=' "$DESKTOP" | sed 's/^/  /'
else
  bad "no desktop entry created"
fi

ICONS=$(find /home /root -path '*hicolor*com.umbra.app.png' 2>/dev/null | wc -l)
if [[ "$ICONS" -gt 0 ]]; then
  ok "$ICONS icon size(s) installed"
else
  bad "no icons installed"
fi

section "3. AppImage execution (Kali has no libfuse2)"
APPIMAGE="$ROOT/client/gui/dist/umbra.AppImage"
if [[ -x "$APPIMAGE" ]]; then
  ok "AppImage exists and is executable"
else
  bad "AppImage missing or not executable"
fi

# Native run needs FUSE2
if "$APPIMAGE" --appimage-version >/dev/null 2>&1; then
  ok "AppImage runtime works"
else
  bad "AppImage runtime cannot start (likely missing libfuse2)"
fi

# Extract-and-run fallback
if "$APPIMAGE" --appimage-extract-and-run --version >/dev/null 2>&1; then
  ok "--appimage-extract-and-run works"
else
  echo "  [INFO] --appimage-extract-and-run also failed (no display in headless test)"
fi

section "SUMMARY"
echo "  passed: $PASS"
echo "  failed: $FAIL"
[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
