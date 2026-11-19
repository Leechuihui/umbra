#!/usr/bin/env bash
# Verify a listener can be created through the API and actually binds.

set -uo pipefail

KEY='admin:CjzeeStPQ9wfCnyH5iwHKzK:BtdxBz5pYq4fcOpFefvwwlmgIrO5elodUC5WZtNb8PJxwD083hEJqOp5CD7esGpbjqcwNGsP8h6XCNFdbaAwLAsZka1L7rlPaFXdLlhUb0lCcNUzO2k0GBebqUyUZMuvVXIGwpnwIWS8cykTHnf3wNA1lbh6mVB83B8geTNeFT3cpVrMfqoH0Rrbt9AkK5JKZdDhkBa6Yl1QQ3yOwhy94xppLnqwwMp5FKCXDVMjiuzBjfue2LpTAHwo8pqncMJ2'
BASE=http://127.0.0.1:9000

echo "=== 1. login ==="
TOKEN=$(curl -s -X POST "$BASE/api/auth/" -H 'Content-Type: application/json' \
  -d "{\"key\":\"$KEY\"}" 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin).get("token",""))' 2>/dev/null)

if [[ -z "$TOKEN" ]]; then
  echo "login failed, trying alternate endpoint..."
  TOKEN=$(curl -s -X POST "$BASE/api/login" -H 'Content-Type: application/json' \
    -d "{\"key\":\"$KEY\"}" 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin).get("token",""))' 2>/dev/null)
fi

if [[ -z "$TOKEN" ]]; then
  echo "could not obtain token"
  echo "--- probing auth endpoints ---"
  for ep in /api/auth /api/login /api/auth/login /api/token; do
    code=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE$ep" -H 'Content-Type: application/json' -d '{}' 2>/dev/null)
    echo "  $ep -> $code"
  done
  exit 1
fi

echo "token acquired (${#TOKEN} chars)"

echo
echo "=== 2. create HTTP listener on 8080 ==="
RESP=$(curl -s -X POST "$BASE/api/listeners/" \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"name":"test-http","listenerType":"channel","channelPayload":"http","host":"0.0.0.0","port":"8080","portToOpen":8080,"implantBodyType":"off"}' 2>/dev/null)
echo "$RESP" | head -c 400
echo

echo
echo "=== 3. is 8080 listening now? ==="
sleep 3
ss -ltn 2>/dev/null | grep ':8080' || echo "8080 NOT listening"

echo
echo "=== 4. list listeners ==="
curl -s "$BASE/api/listeners/" -H "Authorization: Bearer $TOKEN" 2>/dev/null | head -c 500
echo
