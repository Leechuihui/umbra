#!/usr/bin/env bash
# Clean end-to-end verification of the Kali-only workflow.
# Mirrors exactly what the user will do.

set -uo pipefail

ROOT=/opt/umbra
PASS=0
FAIL=0

ok()  { echo "  [OK]   $*"; PASS=$((PASS+1)); }
bad() { echo "  [FAIL] $*"; FAIL=$((FAIL+1)); }
section() { echo; echo "=== $* ==="; }

cd "$ROOT" || { echo "no $ROOT"; exit 1; }

section "1. version"
if ./umbra.py version 2>&1 | grep -q server; then
  ok "CLI works"
  ./umbra.py version 2>&1 | sed 's/^/         /'
else
  bad "CLI broken"
fi

section "2. operator key exists"
if [[ -f "$ROOT/admin.key" ]]; then
  ok "admin.key present"
  echo "         format: $(cut -d: -f1 "$ROOT/admin.key"):<pass>:<secret>"
else
  bad "admin.key missing"
fi

section "3. start server"
pkill -f 'server/main.py' 2>/dev/null || true
sleep 1
setsid nohup ./umbra.py server start > /tmp/srv-clean.log 2>&1 < /dev/null &

for i in $(seq 1 30); do
  ss -ltn 2>/dev/null | grep -q ':9000' && { ok "listening after ${i}s"; break; }
  sleep 1
done

if ! ss -ltn 2>/dev/null | grep -q ':9000'; then
  bad "server did not start"
  tail -15 /tmp/srv-clean.log | sed 's/^/         /'
  exit 1
fi

section "4. HTTP responds (401 = auth guard active)"
code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 http://127.0.0.1:9000/ 2>/dev/null)
if [[ "$code" == "401" ]]; then
  ok "HTTP $code (auth guard working)"
else
  bad "HTTP $code (expected 401)"
fi

section "5. login with the key"
KEY=$(head -1 "$ROOT/admin.key")
U="${KEY%%:*}"; R="${KEY#*:}"; P="${R%%:*}"; S="${R#*:}"
RESP=$(curl -s -X POST http://127.0.0.1:9000/auth/login \
  -H 'Content-Type: application/json' \
  -d "{\"user\":\"$U\",\"pass\":\"$P\",\"secret\":\"$S\"}" 2>/dev/null)
TOKEN=$(echo "$RESP" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("access_token") or "")' 2>/dev/null)
if [[ -n "$TOKEN" ]]; then
  ok "login succeeded (token ${#TOKEN} chars)"
else
  bad "login failed: $(echo "$RESP" | head -c 120)"
fi

section "6. create listener on 8080"
if [[ -n "$TOKEN" ]]; then
  LRESP=$(curl -s -X POST http://127.0.0.1:9000/api/listeners/ \
    -H "Authorization: Bearer $TOKEN" \
    -H 'Content-Type: application/json' \
    -d '{"type":"create","listenerType":"channel","name":"kali-http","channelPayload":"http","host":"0.0.0.0","port":8080,"portToOpen":8080}' 2>/dev/null)
  sleep 3
  if ss -ltn 2>/dev/null | grep -q ':8080'; then
    ok "listener bound on 8080"
  else
    bad "8080 not listening"
    echo "         response: $(echo "$LRESP" | head -c 200)"
  fi
fi

section "7. client binary"
if [[ -x "$ROOT/client/gui/dist/umbra.AppImage" ]]; then
  ok "AppImage present ($(du -h "$ROOT/client/gui/dist/umbra.AppImage" | cut -f1))"
else
  bad "AppImage missing"
fi

section "8. desktop entry"
if [[ -f /home/myroot/.local/share/applications/com.umbra.app.desktop ]]; then
  ok "desktop shortcut exists"
else
  bad "no desktop shortcut"
fi

section "SUMMARY"
echo "  passed: $PASS"
echo "  failed: $FAIL"
echo
echo "  server log: /tmp/srv-clean.log"
[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
