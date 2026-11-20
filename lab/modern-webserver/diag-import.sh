#!/usr/bin/env bash
# Show the full output of importing core.server, unfiltered.
#
# The previous diagnostic showed "IMPORT OK" but no `app` attribute, which means
# the module body ran to completion without ever defining `app`. That can only
# happen if something inside the try/except called exit(1) and the process kept
# going, or if a *different* core.server module was imported. Printing the raw
# output and the module's file path settles which.

set -uo pipefail

SRV=/home/myroot/umbra/server
PY="$SRV/venv/bin/python"

cd "$SRV" || exit 1

echo "=== raw import output ==="
"$PY" - <<'PYEOF' 2>&1 | sed 's/\x1b\[[0-9;]*m//g'
import sys

sys.path.insert(0, ".")
sys.path.insert(0, "core")

import core.server as srv

print("--- module file:", srv.__file__)
print("--- has app:", hasattr(srv, "app"))
print("--- attributes:", [a for a in dir(srv) if not a.startswith("__")][:40])
PYEOF

echo
echo "=== is there more than one server.py? ==="
find "$SRV" -name 'server.py' -not -path '*/venv/*' 2>/dev/null

echo
echo "=== does core/ have an __init__.py? ==="
ls -l "$SRV/core/__init__.py" 2>/dev/null || echo "  no core/__init__.py"
ls -l "$SRV/core/routes/__init__.py" 2>/dev/null || echo "  no core/routes/__init__.py"
