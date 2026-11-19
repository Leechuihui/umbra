#!/usr/bin/env bash
# Keep a single server entry, then restart the client with DevTools enabled.

set -uo pipefail

ROOT=/home/myroot/umbra
CFG=/home/myroot/.config/umbra/config.json
export DISPLAY=:0
export XAUTHORITY=/home/myroot/.Xauthority

echo "=== 1. stop client ==="
pkill -f 'appimage_extracted' 2>/dev/null && echo "  stopped" || echo "  none"
pkill -f 'dist/umbra.AppImage' 2>/dev/null || true
sleep 3

echo
echo "=== 2. dedupe servers, keep the newest ==="
python3 - <<PY
import json

p = "$CFG"
d = json.load(open(p))
servers = d.get("servers") or []

# Keep the last entry (the one created through the GUI).
if len(servers) > 1:
    keep = servers[-1]
    d["servers"] = [keep]
    json.dump(d, open(p, "w"), indent=2)
    open(p, "a").write("\n")
    print(f"  kept: {keep.get('name')!r}  dropped {len(servers) - 1}")
else:
    print(f"  already has {len(servers)} server(s)")

d = json.load(open(p))
for s in d.get("servers") or []:
    print(f"  name={s.get('name')!r} url={s.get('ip')}:{s.get('port')} token_len={len(s.get('token') or '')}")
PY

echo
echo "=== 3. ensure server is up ==="
if ! ss -ltn 2>/dev/null | grep -q ':9000'; then
  cd "$ROOT" || exit 1
  setsid nohup ./umbra.py server start > /tmp/umbra-server.log 2>&1 < /dev/null &
  for i in $(seq 1 30); do
    ss -ltn 2>/dev/null | grep -q ':9000' && break
    sleep 1
  done
fi
ss -ltn 2>/dev/null | grep -q ':9000' && echo "  server listening" || echo "  SERVER DOWN"

echo
echo "=== 4. relaunch client with DevTools ==="
cd "$ROOT/client/gui/dist" || exit 1
setsid nohup ./umbra.AppImage \
  --appimage-extract-and-run \
  --no-sandbox \
  --remote-debugging-port=9222 \
  --remote-allow-origins='*' \
  > /tmp/umbra-client.log 2>&1 < /dev/null &

for i in $(seq 1 40); do
  curl -s --max-time 2 http://127.0.0.1:9222/json/version >/dev/null 2>&1 && { echo "  debug port up after ${i}s"; break; }
  sleep 1
done

sleep 7

echo
echo "=== 5. window + DOM state ==="
wid=$(xdotool search --name 'UMBRA Framework' 2>/dev/null | head -1)
if [[ -n "$wid" ]]; then
  xdotool windowactivate "$wid" 2>/dev/null || true
  xdotool windowsize "$wid" 985 730 2>/dev/null || true
  xdotool windowmove "$wid" 0 0 2>/dev/null || true
  echo "  window id=$wid"
fi

python3 /tmp/cdp.py evalfile /tmp/js-inspect.js 2>&1 | head -30
