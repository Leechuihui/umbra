#!/usr/bin/env bash
# Probe the DevTools protocol endpoints to find the renderer target.

set -uo pipefail

PORT=9222
BASE=http://127.0.0.1:$PORT

echo "=== /json/list ==="
curl -s --max-time 3 "$BASE/json/list" 2>/dev/null | head -c 800
echo

echo
echo "=== /json ==="
curl -s --max-time 3 "$BASE/json" 2>/dev/null | head -c 800
echo

echo
echo "=== parsed targets ==="
for ep in /json/list /json; do
  curl -s --max-time 3 "$BASE$ep" 2>/dev/null | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception as e:
    print(f"  {e}")
    sys.exit(0)
if not isinstance(d, list):
    print(f"  not a list: {type(d).__name__}")
    sys.exit(0)
print(f"  {len(d)} target(s)")
for t in d:
    print(f"    type={t.get(\"type\")} title={t.get(\"title\")!r}")
    print(f"      ws={t.get(\"webSocketDebuggerUrl\",\"\")[:80]}")
' 2>/dev/null
  echo "  ---"
done

echo
echo "=== client process args ==="
pgrep -af 'appimage_extracted' 2>/dev/null | head -2 | cut -c1-200
