#!/usr/bin/env bash
# Verify the bridged-network setup: Kali should be directly reachable from
# the target, so implants no longer need port forwarding.

set -uo pipefail

TARGET=192.168.1.46
HOST=192.168.1.38
LISTENER_PORT=8080

echo "=== 1. Kali addresses ==="
ip -4 addr show eth0 | grep 'inet '

echo
echo "=== 2. Kali -> target ($TARGET) ==="
if ping -c 2 -W 2 "$TARGET" >/dev/null 2>&1; then
  echo "  ping OK"
else
  echo "  ping FAILED"
fi
code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "http://$TARGET/" 2>/dev/null || echo "000")
echo "  http://$TARGET/ -> HTTP $code"

echo
echo "=== 3. Kali -> host ($HOST) ==="
if ping -c 2 -W 2 "$HOST" >/dev/null 2>&1; then
  echo "  ping OK"
else
  echo "  ping FAILED"
fi

echo
echo "=== 4. listener state ==="
ss -ltn 2>/dev/null | grep -E ":9000|:$LISTENER_PORT" || echo "  no listeners"

echo
echo "=== 5. local reachability of the listener ==="
code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 4 "http://127.0.0.1:$LISTENER_PORT/" 2>/dev/null || echo "000")
echo "  http://127.0.0.1:$LISTENER_PORT/ -> HTTP $code"

KALI_IP=$(ip -4 addr show eth0 | awk '/inet /{print $2}' | cut -d/ -f1)
echo
echo "=== 6. reachability over the LAN interface ($KALI_IP) ==="
code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 4 "http://$KALI_IP:$LISTENER_PORT/" 2>/dev/null || echo "000")
echo "  http://$KALI_IP:$LISTENER_PORT/ -> HTTP $code"

echo
echo "=== 7. firewall ==="
if command -v ufw >/dev/null 2>&1; then
  ufw status 2>/dev/null | head -3 || echo "  ufw not readable"
else
  echo "  ufw not installed"
fi
iptables -L INPUT -n 2>/dev/null | head -5 || echo "  iptables not readable"

echo
echo "=== 8. verdict ==="
echo "  Kali IP:     ${KALI_IP:-unknown}"
echo "  target:      $TARGET"
echo "  host:        $HOST"
echo "  C2 address for implants should be: ${KALI_IP:-?}:$LISTENER_PORT"
