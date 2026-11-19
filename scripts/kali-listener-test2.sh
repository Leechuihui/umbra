#!/usr/bin/env bash
# Restart the UMBRA server detached, then create a listener through the API.

set -uo pipefail

ROOT=/opt/umbra
BASE=http://127.0.0.1:9000
KEY='admin:CjzeeStPQ9wfCnyH5iwHKzK:BtdxBz5pYq4fcOpFefvwwlmgIrO5elodUC5WZtNb8PJxwD083hEJqOp5CD7esGpbjqcwNGsP8h6XCNFdbaAwLAsZka1L7rlPaFXdLlhUb0lCcNUzO2k0GBebqUyUZMuvVXIGwpnwIWS8cykTHnf3wNA1lbh6mVB83B8geTNeFT3cpVrMfqoH0Rrbt9AkK5JKZdDhkBa6Yl1QQ3yOwhy94xppLnqwwMp5FKCXDVMjiuzBjfue2LpTAHwo8pqncMJ2'

USER_PART="${KEY%%:*}"
REST="${KEY#*:}"
PASS_PART="${REST%%:*}"
SECRET_PART="${REST#*:}"

echo "=== 1. start server (detached) ==="
pkill -f 'server/main.py' 2>/dev/null || true
sleep 1
cd "$ROOT" || exit 1
setsid nohup ./umbra.py server start > /tmp/srv2.log 2>&1 < /dev/null &

for i in $(seq 1 30); do
  if ss -ltn 2>/dev/null | grep -q ':9000'; then
    echo "server up after ${i}s"
    break
  fi
  sleep 1
done

if ! ss -ltn 2>/dev/null | grep -q ':9000'; then
  echo "SERVER FAILED TO START"
  tail -20 /tmp/srv2.log | sed 's/^/  /'
  exit 1
fi

echo
echo "=== 2. login ==="
RESP=$(curl -s -X POST "$BASE/api/auth/login" \
  -H 'Content-Type: application/json' \
  -d "{\"user\":\"$USER_PART\",\"pass\":\"$PASS_PART\",\"secret\":\"$SECRET_PART\"}" 2>/dev/null)
echo "$RESP" | head -c 200
echo

TOKEN=$(echo "$RESP" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("token") or d.get("access_token") or "")' 2>/dev/null)
if [[ -z "$TOKEN" ]]; then
  echo "NO TOKEN"
  exit 1
fi
echo "token: ${#TOKEN} chars"

echo
echo "=== 3. create HTTP listener on 8080 ==="
LRESP=$(curl -s -X POST "$BASE/api/listeners/" \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"name":"test-http","listenerType":"channel","channelPayload":"http","host":"0.0.0.0","port":"8080","portToOpen":8080,"implantBodyType":"off"}' 2>/dev/null)
echo "$LRESP" | head -c 400
echo

echo
echo "=== 4. is 8080 listening? ==="
sleep 3
ss -ltn 2>/dev/null | grep ':8080' && echo "LISTENER BOUND" || echo "8080 not listening"

echo
echo "=== 5. list listeners ==="
curl -s "$BASE/api/listeners/" -H "Authorization: Bearer $TOKEN" 2>/dev/null | head -c 600
echo
