#!/usr/bin/env bash
# Probe Kali before the WordPress -> UMBRA demo.
#
# Checks: reachability of the modern target, available tooling, and whether the
# UMBRA server is already running.

set -uo pipefail

TARGET=192.168.1.51
UMBRA=/home/myroot/umbra

echo "=== 1. Kali address ==="
ip -4 addr show eth0 2>/dev/null | grep 'inet ' | sed 's/^/  /'

echo
echo "=== 2. reach the target ==="
if ping -c 2 -W 2 "$TARGET" >/dev/null 2>&1; then
  echo "  ping OK"
else
  echo "  ping FAILED"
fi
code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 6 "http://$TARGET/" 2>/dev/null || echo 000)
echo "  http://$TARGET/ -> HTTP $code"

echo
echo "=== 3. tooling ==="
for t in curl wget python3 php wpscan nmap nc; do
  if command -v "$t" >/dev/null 2>&1; then
    printf '  %-8s %s\n' "$t" "$(command -v "$t")"
  else
    printf '  %-8s MISSING\n' "$t"
  fi
done

echo
echo "=== 4. UMBRA server ==="
if ss -ltn 2>/dev/null | grep -q ':9000'; then
  echo "  server listening on 9000"
else
  echo "  server NOT running"
fi
if ss -ltn 2>/dev/null | grep -q ':8080'; then
  echo "  listener on 8080"
else
  echo "  no listener on 8080"
fi

echo
echo "=== 5. UMBRA install ==="
if [[ -d "$UMBRA" ]]; then
  echo "  $UMBRA present"
  [[ -f "$UMBRA/admin.key" ]] && echo "  admin.key present" || echo "  admin.key MISSING"
  [[ -x "$UMBRA/client/gui/dist/umbra.AppImage" ]] && echo "  AppImage present" || echo "  AppImage MISSING"
else
  echo "  $UMBRA MISSING"
fi

echo
echo "=== 6. target fingerprint ==="
curl -s --max-time 8 "http://$TARGET/" 2>/dev/null | grep -oP '(?<=<title>)[^<]*' | head -1 | sed 's/^/  title: /'
curl -s -I --max-time 6 "http://$TARGET/" 2>/dev/null | grep -iE 'server|x-powered' | sed 's/^/  /'
