#!/usr/bin/env bash
# End-to-end callback test.
#
# Decodes the built ELF implant, runs it on Kali, and checks whether a session
# appears on the team server. This proves the whole chain works: implant ->
# listener -> server -> client.

set -uo pipefail

ROOT=/home/myroot/umbra
BASE=http://127.0.0.1:9000
IMPLANT=/tmp/umbra-implant

echo "=== 1. decode the implant from the build response ==="
python3 - <<'PY'
import base64
import json

d = json.load(open('/tmp/build-resp.json'))
raw = d.get('bytes') or ''
if not raw:
    print('  no bytes in the response')
    raise SystemExit(1)

data = base64.b64decode(raw)
with open('/tmp/umbra-implant', 'wb') as f:
    f.write(data)
print('  wrote /tmp/umbra-implant ({} bytes)'.format(len(data)))
print('  magic: {}'.format(data[:4]))
PY

if [[ ! -s "$IMPLANT" ]]; then
  echo "  implant file missing"
  exit 1
fi
chmod +x "$IMPLANT"

echo
echo "=== 2. sessions before running ==="
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

count_sessions() {
  # long_polling=false is required: the default blocks until a session changes.
  curl -s --max-time 8 "$BASE/api/sessions/?long_polling=false" \
    -H "Authorization: Bearer $TOKEN" 2>/dev/null > /tmp/sess.json
  python3 - <<'PY'
import json

try:
    d = json.load(open('/tmp/sess.json'))
except Exception:
    print(0)
    raise SystemExit(0)

items = d.get('sessions') or d.get('active_sessions') or (d if isinstance(d, list) else [])
print(len(items) if isinstance(items, list) else 0)
PY
}

BEFORE=$(count_sessions)
echo "  sessions: $BEFORE"

echo
echo "=== 3. run the implant in the background ==="
pkill -f 'umbra-implant' 2>/dev/null || true
sleep 1
setsid nohup "$IMPLANT" > /tmp/implant-run.log 2>&1 < /dev/null &
echo "  started pid=$!"
sleep 3

echo
echo "=== 4. implant process state ==="
if pgrep -f 'umbra-implant' >/dev/null 2>&1; then
  echo "  running:"
  pgrep -af 'umbra-implant' | sed 's/^/    /'
else
  echo "  NOT running"
  echo "  --- implant log ---"
  tail -15 /tmp/implant-run.log 2>/dev/null | sed 's/^/    /'
fi

echo
echo "=== 5. wait for a session (up to 40s) ==="
AFTER=$BEFORE
for i in $(seq 1 20); do
  sleep 2
  AFTER=$(count_sessions)
  echo "  ${i}: sessions=$AFTER"
  if [[ "$AFTER" -gt "$BEFORE" ]]; then
    echo "  SESSION APPEARED after $((i*2))s"
    break
  fi
done

echo
echo "=== 6. session details ==="
curl -s --max-time 8 "$BASE/api/sessions/?long_polling=false" \
  -H "Authorization: Bearer $TOKEN" 2>/dev/null > /tmp/sess.json
python3 - <<'PY'
import json

try:
    d = json.load(open('/tmp/sess.json'))
except Exception as e:
    print('  cannot parse:', e)
    raise SystemExit(0)

items = d.get('sessions') or d.get('active_sessions') or (d if isinstance(d, list) else [])
if not items:
    print('  no sessions')
    raise SystemExit(0)

for s in items:
    if not isinstance(s, dict):
        continue
    print('  host={} user={} os={} arch={}'.format(
        s.get('hostname') or s.get('host') or '?',
        s.get('username') or s.get('user') or '?',
        s.get('operational_system') or s.get('os') or '?',
        s.get('arch') or '?',
    ))
    print('    tag={} ip={} pid={}'.format(
        s.get('tag') or '?',
        s.get('internal_ip') or s.get('ip') or '?',
        s.get('pid') or '?',
    ))
PY

echo
echo "=== 7. verdict ==="
if [[ "$AFTER" -gt "$BEFORE" ]]; then
  echo "  PASS - implant called back and a session is online"
else
  echo "  FAIL - no session appeared"
  echo "  --- implant log ---"
  tail -20 /tmp/implant-run.log 2>/dev/null | sed 's/^/    /'
  echo "  --- server log ---"
  tail -20 /tmp/umbra-server.log 2>/dev/null | sed 's/^/    /'
fi
