#!/usr/bin/env bash
# Reset UMBRA to a clean state on Kali: stop server, drop test listeners.

set -uo pipefail

ROOT=/opt/umbra
BASE=http://127.0.0.1:9000

cd "$ROOT" || exit 1

echo "=== 1. ensure server is running ==="
if ! ss -ltn 2>/dev/null | grep -q ':9000'; then
  setsid nohup ./umbra.py server start > /tmp/srv-reset.log 2>&1 < /dev/null &
  for i in $(seq 1 30); do
    ss -ltn 2>/dev/null | grep -q ':9000' && break
    sleep 1
  done
fi
ss -ltn 2>/dev/null | grep -q ':9000' && echo "  server up" || { echo "  server down"; exit 1; }

echo
echo "=== 2. login ==="
KEY=$(head -1 "$ROOT/admin.key")
U="${KEY%%:*}"
R="${KEY#*:}"
P="${R%%:*}"
S="${R#*:}"

TOKEN=$(curl -s -X POST "$BASE/auth/login" \
  -H 'Content-Type: application/json' \
  -d "{\"user\":\"$U\",\"pass\":\"$P\",\"secret\":\"$S\"}" 2>/dev/null \
  | python3 -c 'import json,sys; print(json.load(sys.stdin).get("access_token") or "")' 2>/dev/null)

if [[ -z "$TOKEN" ]]; then
  echo "  login failed"
  exit 1
fi
echo "  token ok"

echo
echo "=== 3. list listeners ==="
LIST=$(curl -s "$BASE/api/listeners/" -H "Authorization: Bearer $TOKEN" 2>/dev/null)
echo "$LIST" | head -c 400
echo

echo
echo "=== 4. delete every listener ==="
TAGS=$(echo "$LIST" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)

# The API returns {"status": ..., "active_channels": [...]} but accept
# several shapes so this keeps working if the response changes.
if isinstance(d, list):
    items = d
else:
    items = (
        d.get("active_channels")
        or d.get("listeners")
        or d.get("channels")
        or []
    )

for it in items:
    if not isinstance(it, dict):
        continue
    tag = it.get("tag") or it.get("name")
    if tag:
        print(tag)
' 2>/dev/null)

if [[ -z "$TAGS" ]]; then
  echo "  no listeners to delete"
else
  while IFS= read -r tag; do
    [[ -z "$tag" ]] && continue
    code=$(curl -s -o /dev/null -w '%{http_code}' -X DELETE "$BASE/api/listeners/$tag" \
      -H "Authorization: Bearer $TOKEN" 2>/dev/null)
    echo "  deleted $tag -> HTTP $code"
  done <<< "$TAGS"
fi

echo
echo "=== 5. final state ==="
echo "ports:"
ss -ltn 2>/dev/null | grep -E ':9000|:8080' | sed 's/^/  /' || echo "  none"

echo "listeners:"
curl -s "$BASE/api/listeners/" -H "Authorization: Bearer $TOKEN" 2>/dev/null | head -c 300
echo
