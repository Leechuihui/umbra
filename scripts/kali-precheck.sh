#!/usr/bin/env bash
# Pre-install checks: privileges, network, disk.

set -uo pipefail

echo "=== whoami ==="
whoami
echo "uid=$(id -u)"

echo
echo "=== sudo available ==="
if command -v sudo >/dev/null 2>&1; then
  echo "sudo present"
  if sudo -n true 2>/dev/null; then
    echo "passwordless sudo: YES"
  else
    echo "passwordless sudo: NO (needs password)"
  fi
else
  echo "sudo MISSING"
fi

echo
echo "=== network (github) ==="
curl -fsS -o /dev/null -w "github.com -> %{http_code}\n" --max-time 15 https://github.com 2>&1 || echo "github unreachable"
curl -fsS -o /dev/null -w "deb.nodesource.com -> %{http_code}\n" --max-time 15 https://deb.nodesource.com 2>&1 || echo "nodesource unreachable"

echo
echo "=== apt sources ==="
ls /etc/apt/sources.list.d/ 2>/dev/null | head -5

echo
echo "=== disk ==="
df -h / | tail -1

echo
echo "=== script perms in /tmp/umbra ==="
ls -l /tmp/umbra/install.sh /tmp/umbra/install/linux.sh /tmp/umbra/umbra.py 2>&1
