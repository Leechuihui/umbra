#!/usr/bin/env bash
# Diagnose the HTTP 500 returned by the WordPress plugin upload.

set -uo pipefail

PW_FILE=/tmp/.umbra-pw
sudo_run() {
  if [[ -r "$PW_FILE" ]]; then
    sudo -S -p '' "$@" < "$PW_FILE"
  else
    sudo -n "$@"
  fi
}

echo "=== 1. nginx error log (last 20) ==="
sudo_run tail -20 /var/log/nginx/error.log 2>/dev/null | sed 's/^/  /' || echo "  (none)"

echo
echo "=== 2. php8.2-fpm log (last 20) ==="
sudo_run tail -20 /var/log/php8.2-fpm.log 2>/dev/null | sed 's/^/  /' || echo "  (none)"

echo
echo "=== 3. wordpress debug.log ==="
if sudo_run test -f /var/www/html/wp-content/debug.log; then
  sudo_run tail -30 /var/www/html/wp-content/debug.log 2>/dev/null | sed 's/^/  /'
else
  echo "  (no debug.log)"
fi

echo
echo "=== 4. PHP limits ==="
php -i 2>/dev/null | grep -E '^upload_max_filesize|^post_max_size|^memory_limit|^max_execution_time' | sed 's/^/  /'

echo
echo "=== 5. disk space ==="
df -h / | tail -1 | sed 's/^/  /'

echo
echo "=== 6. wp-content permissions ==="
ls -ld /var/www/html/wp-content /var/www/html/wp-content/plugins 2>/dev/null | sed 's/^/  /'

echo
echo "=== 7. plugins directory ==="
ls -1 /var/www/html/wp-content/plugins 2>/dev/null | sed 's/^/  /'

echo
echo "=== 8. filesystem writability for www-data ==="
sudo_run -u www-data test -w /var/www/html/wp-content/plugins \
  && echo "  www-data CAN write to plugins/" \
  || echo "  www-data CANNOT write to plugins/"
