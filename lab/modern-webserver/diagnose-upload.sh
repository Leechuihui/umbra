#!/usr/bin/env bash
# Find out why the WordPress plugin upload returns HTTP 500.
#
# Checks the two most likely causes:
#   1. the PHP zip extension is missing, so WordPress cannot unpack the plugin
#   2. a PHP fatal that only shows up with WP_DEBUG_LOG enabled
#
# Then enables debug logging so the next upload attempt records the real error.

set -uo pipefail

PW_FILE=/tmp/.umbra-pw
sudo_run() {
  if [[ -r "$PW_FILE" ]]; then
    sudo -S -p '' "$@" < "$PW_FILE"
  else
    sudo -n "$@"
  fi
}

echo "=== 1. PHP extensions relevant to plugin upload ==="
for ext in zip zlib fileinfo mbstring; do
  if php -m 2>/dev/null | grep -qix "$ext"; then
    echo "  [OK] $ext"
  else
    echo "  [--] $ext  MISSING"
  fi
done

echo
echo "=== 2. ZipArchive class available? ==="
php -r 'echo class_exists("ZipArchive") ? "  [OK] ZipArchive\n" : "  [--] ZipArchive MISSING\n";' 2>&1

echo
echo "=== 3. disabled PHP functions ==="
php -i 2>/dev/null | grep -E '^disable_functions' | sed 's/^/  /'

echo
echo "=== 4. enable WP_DEBUG_LOG ==="
WP_CONFIG=/var/www/html/wp-config.php
if sudo_run grep -q "WP_DEBUG_LOG" "$WP_CONFIG" 2>/dev/null; then
  echo "  already configured"
else
  # WordPress ships with WP_DEBUG set to false. Comment it out first.
  sudo_run sed -i "s/define( 'WP_DEBUG', false );/\/\/ define( 'WP_DEBUG', false );/" "$WP_CONFIG"
  sudo_run sed -i "/That's all, stop editing/i\\
define('WP_DEBUG', true);\\
define('WP_DEBUG_LOG', '/var/www/html/wp-content/debug.log');\\
define('WP_DEBUG_DISPLAY', false);\\
" "$WP_CONFIG"
  echo "  fixed debug settings"
fi
sudo_run grep -nE "WP_DEBUG" "$WP_CONFIG" 2>/dev/null | sed 's/^/  /'

echo
echo "=== 5. make sure the log is writable ==="
sudo_run touch /var/www/html/wp-content/debug.log 2>/dev/null
sudo_run chown www-data:www-data /var/www/html/wp-content/debug.log 2>/dev/null
sudo_run chmod 666 /var/www/html/wp-content/debug.log 2>/dev/null
ls -l /var/www/html/wp-content/debug.log 2>/dev/null | sed 's/^/  /'

echo
echo "=== 6. clear the log so the next attempt is unambiguous ==="
sudo_run truncate -s 0 /var/www/html/wp-content/debug.log 2>/dev/null
echo "  cleared"

echo
echo "=== 7. done - retry the upload now ==="
