#!/usr/bin/env bash
# Diagnose why the UMBRA server exits right after printing its banner.
#
# The banner comes from launcher/utils/ascii.py, so the process dies inside
# main_start() before uvicorn binds the port. There is no traceback on stdout,
# which usually means the exception was swallowed or the process was replaced.
#
# This script imports the app directly with the venv interpreter and prints the
# real exception, then checks the config the launcher reads.

set -uo pipefail

SRV=/home/myroot/umbra/server
PY="$SRV/venv/bin/python"

echo "=== 1. interpreter ==="
"$PY" -V

echo
echo "=== 2. import core.server directly (this is what uvicorn loads) ==="
cd "$SRV" || exit 1
"$PY" - <<'PYEOF' 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | tail -30
import sys, traceback

sys.path.insert(0, ".")
sys.path.insert(0, "core")

try:
    import core.server as srv
    print("IMPORT OK")
    print("app:", srv.app)
except SystemExit as e:
    print("SystemExit during import, code =", e.code)
except BaseException:
    print("EXCEPTION during import:")
    traceback.print_exc()
PYEOF

echo
echo "=== 3. config the launcher reads ==="
"$PY" - <<'PYEOF' 2>&1 | tail -20
import sys
sys.path.insert(0, ".")
try:
    from launcher.utils.config import config
    srv = config["config"]
    for k in ("host", "port", "workers", "reload", "certfile", "keyfile"):
        print(f"  {k} = {srv.get(k)!r}")
except BaseException as e:
    print("config load failed:", type(e).__name__, e)
PYEOF

echo
echo "=== 4. does the port bind at all? ==="
ss -ltn 2>/dev/null | grep -E ':9000' || echo "  nothing on 9000"

echo
echo "=== 5. server log from the last attempt ==="
if [[ -f /tmp/srv-fg.log ]]; then
  sed 's/\x1b\[[0-9;]*m//g' /tmp/srv-fg.log | grep -aiE 'error|traceback|exception|failed|running on|OK' | head -20 || echo "  (no error lines)"
else
  echo "  no /tmp/srv-fg.log"
fi
