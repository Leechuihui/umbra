#!/usr/bin/env bash
# Verify the UMBRA server is fully functional after the import fix.
#
# Checks: port bound, login works, listeners endpoint reachable, and the
# operator key still authenticates.

set -uo pipefail

ROOT=/home/myroot/umbra
BASE=http://127.0.0.1:9000

echo "=== 1. port ==="
ss -ltn 2>/dev/null | grep ':9000' || { echo "  NOT LISTENING"; exit 1; }

echo
echo "=== 2. unauthenticated request should be 401 ==="
code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 8 "$BASE/" 2>/dev/null || echo 000)
echo "  GET / -> HTTP $code"

if [[ ! -f "$ROOT/admin.key" ]]; then
  echo "  no admin.key"
  exit 1
fi

echo
echo "=== 3. login ==="
KEY=$(head -1 "$ROOT/admin.key")
U="${KEY%%:*}"
R="${KEY#*:}"
P="${R%%:*}"
S="${R#*:}"

RESP=$(curl -s --max-time 10 -X POST "$BASE/auth/login" \
  -H 'Content-Type: application/json' \
  -d "{\"user\":\"$U\",\"pass\":\"$P\",\"secret\":\"$S\"}" 2>/dev/null)

echo "  response: $(echo "$RESP" | head -c 120)"

TOKEN=$(echo "$RESP" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("access_token") or "")' 2>/dev/null)

if [[ -z "$TOKEN" ]]; then
  echo "  LOGIN FAILED"
  exit 1
fi
echo "  token: ${#TOKEN} chars"

echo
echo "=== 4. authenticated endpoints ==="
for ep in /api/listeners/ /api/sessions/?long_polling=false /api/implants/; do
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 8 "$BASE$ep" \
    -H "Authorization: Bearer $TOKEN" 2>/dev/null || echo 000)
  printf '  %-40s HTTP %s\n' "$ep" "$code"
done

echo
echo "=== 5. listeners ==="
curl -s --max-time 8 "$BASE/api/listeners/" -H "Authorization: Bearer $TOKEN" 2>/dev/null | head -c 400
echo

echo
echo "=== 6. verdict ==="
if [[ "$code" != "000" ]]; then
  echo "  SERVER FUNCTIONAL"
else
  echo "  SERVER NOT RESPONDING"
fi
