#!/usr/bin/env bash
# Corrected HTTP probe: the root path returns 404 by design, so probe real
# endpoints and accept any HTTP status as proof the server responds.

set -uo pipefail

ROOT=/opt/umbra
cd "$ROOT" || exit 1

./umbra.py server start > /tmp/server-run2.log 2>&1 &
SRV_PID=$!
sleep 12

echo "=== listening ==="
ss -ltnp 2>/dev/null | grep ':9000' || echo "not listening"

echo
echo "=== endpoint probes (any HTTP code = server alive) ==="
for path in / /docs /openapi.json /api/sessions/ /api/listeners/; do
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "http://127.0.0.1:9000${path}" 2>/dev/null || echo "000")
  printf '  %-20s -> HTTP %s\n' "$path" "$code"
done

echo
echo "=== openapi title (proves FastAPI app loaded) ==="
curl -s --max-time 5 http://127.0.0.1:9000/openapi.json 2>/dev/null \
  | python3 -c 'import json,sys; d=json.load(sys.stdin); print("  title:", d.get("info",{}).get("title")); print("  paths:", len(d.get("paths",{})))' 2>/dev/null \
  || echo "  (could not parse openapi)"

echo
echo "=== server log tail ==="
tail -8 /tmp/server-run2.log | sed 's/^/  /'

kill $SRV_PID 2>/dev/null || true
wait $SRV_PID 2>/dev/null || true
pkill -f 'main.py' 2>/dev/null || true
echo
echo "done"
