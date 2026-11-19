#!/usr/bin/env bash
# Reset Kali to a clean, working state before driving the GUI.
#
# Problems found:
#   - config.json was hand-edited into invalid JSON: {"servers": [192.168.1.46]}
#   - four server processes running from two different install dirs
#   - /opt/umbra was deleted while its processes still held the files open

set -uo pipefail

ROOT=/home/myroot/umbra
CFG=/home/myroot/.config/umbra/config.json

echo "=== 1. stop every umbra process ==="
pkill -f 'server/main.py' 2>/dev/null && echo "  killed server(s)" || echo "  no server"
pkill -f 'appimage_extracted' 2>/dev/null && echo "  killed client (extracted)" || echo "  no extracted client"
pkill -f 'dist/umbra.AppImage' 2>/dev/null && echo "  killed client (AppImage)" || echo "  no AppImage"
sleep 3

remaining=$(pgrep -fc 'server/main.py|appimage_extracted' 2>/dev/null || echo 0)
echo "  remaining processes: $remaining"

if [[ "$remaining" -gt 0 ]]; then
  echo "  force killing..."
  pkill -9 -f 'server/main.py' 2>/dev/null || true
  pkill -9 -f 'appimage_extracted' 2>/dev/null || true
  sleep 2
fi

echo
echo "=== 2. repair client config ==="
mkdir -p "$(dirname "$CFG")"
if [[ -f "$CFG" ]]; then
  backup="$CFG.broken.$(date +%s)"
  cp "$CFG" "$backup" 2>/dev/null && echo "  backed up broken file -> $backup"
fi

printf '{\n  "servers": []\n}\n' > "$CFG"
echo "  wrote clean config:"
cat "$CFG" | sed 's/^/    /'

echo
echo "=== 3. validate JSON ==="
if python3 -c "import json; json.load(open('$CFG'))" 2>/dev/null; then
  echo "  config.json is valid JSON"
else
  echo "  STILL INVALID"
  exit 1
fi

echo
echo "=== 4. start server from $ROOT ==="
cd "$ROOT" || { echo "  no $ROOT"; exit 1; }
setsid nohup ./umbra.py server start > /tmp/umbra-server.log 2>&1 < /dev/null &

for i in $(seq 1 30); do
  if ss -ltn 2>/dev/null | grep -q ':9000'; then
    echo "  listening after ${i}s"
    break
  fi
  sleep 1
done

if ! ss -ltn 2>/dev/null | grep -q ':9000'; then
  echo "  SERVER FAILED TO START"
  tail -25 /tmp/umbra-server.log | sed 's/^/    /'
  exit 1
fi

echo
echo "=== 5. verify the operator key still authenticates ==="
KEY=$(head -1 "$ROOT/admin.key")
U="${KEY%%:*}"
R="${KEY#*:}"
P="${R%%:*}"
S="${R#*:}"

echo "  user=$U  pass_len=${#P}  secret_len=${#S}"

RESP=$(curl -s -X POST http://127.0.0.1:9000/auth/login \
  -H 'Content-Type: application/json' \
  -d "{\"user\":\"$U\",\"pass\":\"$P\",\"secret\":\"$S\"}" 2>/dev/null)

echo "  response: $(echo "$RESP" | head -c 140)"

TOKEN=$(echo "$RESP" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("access_token") or "")' 2>/dev/null)
if [[ -n "$TOKEN" ]]; then
  echo "  LOGIN OK (token ${#TOKEN} chars)"
else
  echo "  LOGIN FAILED"
fi

echo
echo "=== 6. final state ==="
echo "  ports:"
ss -ltn 2>/dev/null | grep -E ':9000|:8080' | sed 's/^/    /' || echo "    none"
echo "  processes:"
pgrep -af 'server/main.py' 2>/dev/null | sed 's/^/    /' || echo "    none"
