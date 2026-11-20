#!/usr/bin/env bash
# Manually fix the duplicate WP_DEBUG definition in wp-config.php.
#
# The previous script tried to comment out the original line, but either
# missed or was racing with another process. This one does it directly.

set -uo pipefail

PW_FILE=/tmp/.umbra-pw
sudo_run() {
  if [[ -r "$PW_FILE" ]]; then
    sudo -S -p '' "$@" < "$PW_FILE"
  else
    sudo -n "$@"
  fi
}

echo "=== 1. current WP_DEBUG lines ==="
sudo_run grep -n "WP_DEBUG" /var/www/html/wp-config.php 2>/dev/null | sed 's/^/  /'

echo
echo "=== 2. fix the duplicate ==="
# Comment out the original false line if it's still active.
sudo_run sed -i "s/define( 'WP_DEBUG', false );/\/\/ define( 'WP_DEBUG', false );  <-- was conflicting/" /var/www/html/wp-config.php
echo "  commented out original"

# Make sure our new block is there.
sudo_run grep -q "define('WP_DEBUG_LOG', '/var/www/html/wp-content/debug.log')" /var/www/html/wp-config.php || {
  sudo_run sed -i "/That's all, stop editing/i\\
define('WP_DEBUG', true);\\
define('WP_DEBUG_LOG', '/var/www/html/wp-content/debug.log');\\
define('WP_DEBUG_DISPLAY', false);\\
" /var/www/html/wp-config.php
  echo "  added debug block"
}

echo
echo "=== 3. final WP_DEBUG lines ==="
sudo_run grep -n "WP_DEBUG" /var/www/html/wp-config.php 2>/dev/null | sed 's/^/  /'

echo
echo "=== 4. clear debug log ==="
sudo_run truncate -s 0 /var/www/html/wp-content/debug.log 2>/dev/null
echo "  cleared"
