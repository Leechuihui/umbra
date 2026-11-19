#!/usr/bin/env bash
# Diagnose why the listener panel's server dropdown is empty.

set -uo pipefail

BASE=http://127.0.0.1:9000
KEYFILE=/opt/umbra/admin.key

if [[ ! -f "$KEYFILE" ]]; then
  echo "missing $KEYFILE"
  exit 1
fi

KEY=$(head -1 "$KEYFILE")
USER_PART="${KEY%%:*}"
REST="${KEY#*:}"
PASS_PART="${REST%%:*}"
SECRET_PART="${REST#*:}"

echo "=== 1. server listening? ==="
ss -ltn 2>/dev/null | grep ':9000' || { echo "SERVER DOWN"; exit 1; }

echo
echo "=== 2. auth endpoint (correct path: /auth/login) ==="
RESP=$(curl -s -X POST "$BASE/auth/login" \
  -H 'Content-Type: application/json' \
  -d "{\"user\":\"$USER_PART\",\"pass\":\"$PASS_PART\",\"secret\":\"$SECRET_PART\"}" 2>/dev/null)
echo "$RESP" | head -c 200
echo

TOKEN=$(echo "$RESP" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("access_token") or "")' 2>/dev/null)
if [[ -z "$TOKEN" ]]; then
  echo "AUTH FAILED - cannot get token"
  exit 1
fi
echo "token OK (${#TOKEN} chars)"

echo
echo "=== 3. client config.json (this is what feeds the dropdown) ==="
for f in /home/myroot/.config/umbra/config.json /root/.config/umbra/config.json; do
  if [[ -f "$f" ]]; then
    echo "$f:"
    cat "$f" | head -20
  fi
done

echo
echo "=== 4. servers count in config ==="
python3 -c "
import json, os
for p in ['/home/myroot/.config/umbra/config.json', '/root/.config/umbra/config.json']:
    if os.path.exists(p):
        d = json.load(open(p))
        print(f'{p}: {len(d.get(\"servers\", []))} server(s)')
" 2>/dev/null

echo
echo "=== 5. conclusion ==="
COUNT=$(python3 -c "
import json, os
n = 0
for p in ['/home/myroot/.config/umbra/config.json', '/root/.config/umbra/config.json']:
    if os.path.exists(p):
        n += len(json.load(open(p)).get('servers', []))
print(n)
" 2>/dev/null || echo 0)

if [[ "$COUNT" -eq 0 ]]; then
  echo "config has 0 servers -> listener dropdown is EMPTY (this is the cause)"
else
  echo "config has $COUNT server(s) -> dropdown should have options"
fi
