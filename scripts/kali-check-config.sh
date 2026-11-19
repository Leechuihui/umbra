#!/usr/bin/env bash
# Report the client config after the GUI auth.

CFG=/home/myroot/.config/umbra/config.json

echo "=== config.json ==="
cat "$CFG" 2>/dev/null || echo "missing"

echo
echo "=== parsed ==="
python3 - <<PY
import json
p = "$CFG"
try:
    d = json.load(open(p))
except Exception as e:
    print(f"  invalid JSON: {e}")
    raise SystemExit(1)
servers = d.get("servers") or []
print(f"  servers: {len(servers)}")
for i, s in enumerate(servers):
    print(f"    [{i}] name={s.get('name')!r} url={s.get('ip')}:{s.get('port')} token_len={len(s.get('token') or '')}")
PY

echo
echo "=== listeners on the server ==="
KEY=$(head -1 /home/myroot/umbra/admin.key)
U="${KEY%%:*}"; R="${KEY#*:}"; P="${R%%:*}"; S="${R#*:}"
TOKEN=$(curl -s -X POST http://127.0.0.1:9000/auth/login \
  -H 'Content-Type: application/json' \
  -d "{\"user\":\"$U\",\"pass\":\"$P\",\"secret\":\"$S\"}" 2>/dev/null \
  | python3 -c 'import json,sys; print(json.load(sys.stdin).get("access_token") or "")' 2>/dev/null)

curl -s http://127.0.0.1:9000/api/listeners/ -H "Authorization: Bearer $TOKEN" 2>/dev/null | head -c 400
echo

echo
echo "=== ports ==="
ss -ltn 2>/dev/null | grep -E ':9000|:8080' || echo "  none"
