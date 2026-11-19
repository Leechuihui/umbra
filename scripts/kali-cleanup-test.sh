#!/usr/bin/env bash
# Clean up after the callback test: stop the implant, drop the test session.

set -uo pipefail

ROOT=/home/myroot/umbra
BASE=http://127.0.0.1:9000

echo "=== 1. stop the test implant ==="
pkill -f 'umbra-implant' 2>/dev/null && echo "  stopped" || echo "  not running"
sleep 2

echo
echo "=== 2. login ==="
KEY=$(head -1 "$ROOT/admin.key")
U="${KEY%%:*}"; R="${KEY#*:}"; P="${R%%:*}"; S="${R#*:}"
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
echo "=== 3. list sessions ==="
curl -s --max-time 8 "$BASE/api/sessions/?long_polling=false" \
  -H "Authorization: Bearer $TOKEN" 2>/dev/null > /tmp/sess.json
python3 - <<'PY'
import json

try:
    d = json.load(open('/tmp/sess.json'))
except Exception:
    print('  cannot parse')
    raise SystemExit(0)

items = d.get('sessions') or d.get('active_sessions') or (d if isinstance(d, list) else [])
print('  sessions: {}'.format(len(items) if isinstance(items, list) else 0))
for s in (items if isinstance(items, list) else []):
    if isinstance(s, dict):
        print('    tag={} host={}'.format(s.get('tag'), s.get('hostname')))
PY

echo
echo "=== 4. delete every session ==="
TAGS=$(python3 - <<'PY'
import json

try:
    d = json.load(open('/tmp/sess.json'))
except Exception:
    raise SystemExit(0)

items = d.get('sessions') or d.get('active_sessions') or (d if isinstance(d, list) else [])
for s in (items if isinstance(items, list) else []):
    if isinstance(s, dict) and s.get('tag'):
        print(s['tag'])
PY
)

if [[ -z "$TAGS" ]]; then
  echo "  none to delete"
else
  while IFS= read -r tag; do
    [[ -z "$tag" ]] && continue
    code=$(curl -s -o /dev/null -w '%{http_code}' -X DELETE "$BASE/api/sessions/$tag" \
      -H "Authorization: Bearer $TOKEN" 2>/dev/null)
    echo "  deleted $tag -> HTTP $code"
  done <<< "$TAGS"
fi

echo
echo "=== 5. remove the implant binary ==="
rm -f /tmp/umbra-implant /tmp/implant-run.log /tmp/build-resp.json /tmp/build-body.json /tmp/sess.json /tmp/l.json
echo "  removed temp files"

echo
echo "=== 6. final state ==="
echo "  ports:"
ss -ltn 2>/dev/null | grep -E ':9000|:8080' | sed 's/^/    /' || echo "    none"
echo "  sessions:"
curl -s --max-time 8 "$BASE/api/sessions/?long_polling=false" \
  -H "Authorization: Bearer $TOKEN" 2>/dev/null | head -c 200
echo
echo "  disk:"
df -h /tmp | tail -1 | sed 's/^/    /'
