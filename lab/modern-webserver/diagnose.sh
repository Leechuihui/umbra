#!/usr/bin/env bash
# Diagnose the modern webserver VM: cloud-init status, packages, services.

echo "=== 1. cloud-init status ==="
cloud-init status --long 2>&1 | head -20

echo
echo "=== 2. cloud-init errors ==="
sudo grep -iE 'error|fail|traceback' /var/log/cloud-init-output.log 2>/dev/null | head -15 || echo "  none"

echo
echo "=== 3. cloud-init output tail ==="
sudo tail -25 /var/log/cloud-init-output.log 2>/dev/null

echo
echo "=== 4. installed web packages ==="
dpkg -l 2>/dev/null | grep -E '^ii.*(nginx|mariadb|php)' | awk '{print "  "$2" "$3}' | head -20 || echo "  none"

echo
echo "=== 5. services ==="
for s in nginx mariadb php8.2-fpm; do
  state=$(systemctl is-active "$s" 2>/dev/null || echo "not-found")
  echo "  $s: $state"
done

echo
echo "=== 6. web root ==="
ls -la /var/www/html 2>/dev/null | head -10 || echo "  missing"

echo
echo "=== 7. disk and memory ==="
df -h / | tail -1
free -h | head -2

echo
echo "=== 8. network ==="
ip -4 addr show | grep -E '^[0-9]+:|inet ' | sed 's/^/  /'
