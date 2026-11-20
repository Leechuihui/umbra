#!/usr/bin/env bash
# Start UMBRA server and open the GUI.
#
# This script assumes:
#   - UMBRA is installed in /home/myroot/umbra
#   - admin.key is present
#   - the AppImage is built
#   - X11 forwarding is set up (for the GUI)

set -uo pipefail

UMBRA_HOME=/home/myroot/umbra

echo "=== 1. check UMBRA components ==="
ls -l "$UMBRA_HOME/admin.key" 2>/dev/null && echo "  admin.key OK" || echo "  admin.key MISSING"
ls -l "$UMBRA_HOME/client/gui/dist/umbra.AppImage" 2>/dev/null && echo "  AppImage OK" || echo "  AppImage MISSING"

UMBRA_SERVER_PID=

echo
echo "=== 2. start the server ==="
if pgrep -f "umbra[.]py.*server" >/dev/null 2>&1; then
  echo "  server already running"
else
  cd "$UMBRA_HOME/server" || exit 1
  python3 umbra.py server --admin-key-file ../admin.key > /tmp/umbra-server.log 2>&1 &
  UMBRA_SERVER_PID=$!
  echo "  server started (PID $UMBRA_SERVER_PID)"
  sleep 3
fi

echo
echo "=== 3. launch the GUI ==="
cd "$UMBRA_HOME/client/gui/dist" || exit 1
DISPLAY=:0 ./umbra.AppImage &
GUI_PID=$!
echo "  GUI started (PID $GUI_PID)"

if [[ -n "${UMBRA_SERVER_PID}" ]]; then
  echo
echo "=== 4. server log (first 20 lines) ==="
  head -20 /tmp/umbra-server.log 2>/dev/null | sed 's/^/  /'
fi

echo
echo "=== 5. done ==="
echo "  You can now connect to http://192.168.1.51/wp-content/plugins/umbra-shell/umbra-shell.php?umbra_cmd=id"
echo "  in the UMBRA GUI."
