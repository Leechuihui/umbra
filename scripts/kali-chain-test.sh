#!/usr/bin/env bash
# Verify the NAT port-forward chain: target -> host:8080 -> Kali:8080
# Kali sits behind NAT, so an implant cannot reach it directly.

set -uo pipefail

PORT=8080

echo "=== Kali IP (NAT) ==="
ip -4 addr show eth0 | grep 'inet '

echo
echo "=== starting listener on Kali:$PORT ==="
rm -f /tmp/chain-recv.txt
( timeout 30 nc -l -p "$PORT" > /tmp/chain-recv.txt 2>/dev/null & )
sleep 2
if ss -ltn 2>/dev/null | grep -q ":$PORT"; then
  echo "listener up on $PORT"
else
  echo "listener FAILED to bind"
  exit 1
fi

echo
echo "=== waiting for inbound connection (host -> 192.168.1.38:$PORT) ==="
for i in $(seq 1 25); do
  if [[ -s /tmp/chain-recv.txt ]]; then
    echo "RECEIVED after ${i}s:"
    head -3 /tmp/chain-recv.txt | sed 's/^/  /'
    exit 0
  fi
  sleep 1
done

echo "no data received within 25s"
exit 1
