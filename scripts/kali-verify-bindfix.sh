#!/usr/bin/env bash
# Verify the listener now binds to 0.0.0.0 (the bind-address fix).

set -uo pipefail

ROOT=/home/myroot/umbra
BASE=http://127.0.0.1:9000

echo "=== 1. port bindings ==="
ss -ltn 2>/dev/null | grep -E ':9000|:8080' || echo "  none"

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
echo "=== 3. listener record ==="
curl -s "$BASE/api/listeners/" -H "Authorization: Bearer $TOKEN" 2>/dev/null > /tmp/listeners.json
python3 - <<'PY'
import json

with open('/tmp/listeners.json', encoding='utf-8') as f:
    d = json.load(f)

for ch in (d.get('active_channels') or []):
    print('  name={}'.format(ch.get('name')))
    print('  host={}  port={}  tag={}'.format(ch.get('host'), ch.get('port'), ch.get('tag')))
    print('  protocol={}  payload={}'.format(ch.get('protocol'), ch.get('channelPayload')))
PY

echo
echo "=== 4. reachability test from the host IP ==="
HOSTIP=$(ip -4 addr show eth0 2>/dev/null | awk '/inet /{print $2}' | cut -d/ -f1)
echo "  kali eth0 ip: ${HOSTIP:-unknown}"
if [[ -n "${HOSTIP:-}" ]]; then
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 4 "http://$HOSTIP:8080/" 2>/dev/null || echo "000")
  echo "  http://$HOSTIP:8080/ -> HTTP $code"
  if [[ "$code" != "000" ]]; then
    echo "  listener accepts connections on the network interface"
  else
    echo "  no response (listener may need a moment or a valid request)"
  fi
fi

echo
echo "=== 5. verdict ==="
BOUND=$(ss -ltn 2>/dev/null | grep ':8080' | awk '{print $4}')
echo "  bound address: ${BOUND:-none}"
if [[ "$BOUND" == 0.0.0.0:8080 ]]; then
  echo "  PASS - listening on all interfaces"
elif [[ "$BOUND" == 127.0.0.1:8080 ]]; then
  echo "  FAIL - still bound to loopback only"
else
  echo "  unexpected: $BOUND"
fi
