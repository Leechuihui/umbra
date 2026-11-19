#!/usr/bin/env bash
# Configure the UMBRA client so the listener panel's server dropdown works.
#
# Equivalent to: UMBRA > Servers > Add > paste key > Auth
# but done by writing config.json directly with a freshly minted JWT.

set -uo pipefail

ROOT=/home/myroot/umbra
CFG=/home/myroot/.config/umbra/config.json
export DISPLAY=:0
export XAUTHORITY=/home/myroot/.Xauthority

echo "=== 1. stop the client so it does not overwrite config ==="
pkill -f 'appimage_extracted' 2>/dev/null && echo "  stopped" || echo "  not running"
sleep 2

echo
echo "=== 2. make sure the server is up ==="
if ! ss -ltn 2>/dev/null | grep -q ':9000'; then
  echo "  server down, starting..."
  cd "$ROOT" || exit 1
  setsid nohup ./umbra.py server start > /tmp/umbra-server.log 2>&1 < /dev/null &
  for i in $(seq 1 30); do
    ss -ltn 2>/dev/null | grep -q ':9000' && break
    sleep 1
  done
fi
ss -ltn 2>/dev/null | grep -q ':9000' && echo "  server listening" || { echo "  SERVER DOWN"; exit 1; }

echo
echo "=== 3. log in to mint a JWT ==="
KEY=$(head -1 "$ROOT/admin.key")
U="${KEY%%:*}"
R="${KEY#*:}"
P="${R%%:*}"
S="${R#*:}"

RESP=$(curl -s -X POST http://127.0.0.1:9000/auth/login \
  -H 'Content-Type: application/json' \
  -d "{\"user\":\"$U\",\"pass\":\"$P\",\"secret\":\"$S\"}" 2>/dev/null)

TOKEN=$(echo "$RESP" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("access_token") or "")' 2>/dev/null)
if [[ -z "$TOKEN" ]]; then
  echo "  LOGIN FAILED: $(echo "$RESP" | head -c 160)"
  exit 1
fi
echo "  token ok (${#TOKEN} chars)"

echo
echo "=== 4. verify the token actually works ==="
code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:9000/api/listeners/ \
  -H "Authorization: Bearer $TOKEN" 2>/dev/null)
echo "  GET /api/listeners/ -> HTTP $code"
if [[ "$code" != "200" ]]; then
  echo "  token rejected, aborting"
  exit 1
fi

echo
echo "=== 5. write config.json ==="
mkdir -p "$(dirname "$CFG")"

U="$U" P="$P" S="$S" TOKEN="$TOKEN" CFG="$CFG" python3 <<'PY'
import json, os

cfg_path = os.environ["CFG"]
entry = {
    "id": "kali-local",
    "name": "kali-local",
    "ip": "http://127.0.0.1",
    "port": "9000",
    "user": os.environ["U"],
    "pass": os.environ["P"],
    "secret": os.environ["S"],
    "token": os.environ["TOKEN"],
}
with open(cfg_path, "w", encoding="utf-8") as f:
    json.dump({"servers": [entry]}, f, indent=2)
    f.write("\n")
print("  wrote", cfg_path)
PY

echo
echo "=== 6. validate the written config ==="
python3 - <<PY
import json
p = "$CFG"
d = json.load(open(p))
servers = d.get("servers") or []
print(f"  servers: {len(servers)}")
for s in servers:
    print(f"    name={s['name']}  url={s['ip']}:{s['port']}  token_len={len(s['token'])}")
PY

echo
echo "=== 7. launch the client ==="
cd "$ROOT/client/gui/dist" || exit 1
setsid nohup ./umbra.AppImage --appimage-extract-and-run --no-sandbox \
  > /tmp/umbra-client.log 2>&1 < /dev/null &

echo "  waiting for the window..."
for i in $(seq 1 40); do
  if xdotool search --class 'umbra' >/dev/null 2>&1; then
    echo "  window up after ${i}s"
    break
  fi
  sleep 1
done
sleep 6

echo
echo "=== 8. windows on :0 ==="
while IFS= read -r wid; do
  [[ -z "$wid" ]] && continue
  name=$(xdotool getwindowname "$wid" 2>/dev/null || echo "?")
  geo=$(xdotool getwindowgeometry --shell "$wid" 2>/dev/null | tr '\n' ' ' || echo "?")
  echo "  id=$wid name='$name' $geo"
done < <(xdotool search --onlyvisible --name '.' 2>/dev/null | head -20)

echo
echo "=== 9. screenshot ==="
import -window root /tmp/umbra-ready.png 2>/dev/null \
  && echo "  saved /tmp/umbra-ready.png ($(du -h /tmp/umbra-ready.png | cut -f1))" \
  || echo "  screenshot failed"

echo
echo "=== 10. client log ==="
tail -8 /tmp/umbra-client.log 2>/dev/null | sed 's/^/  /' || echo "  empty"
