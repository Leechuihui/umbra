#!/usr/bin/env bash
# Try installing the plugin manually to bypass the HTTP 500.
#
# If WordPress can unpack and activate it from a local file, the RCE part
# of the demo will still work. We just won't get to show the upload exploit
# in the video.

set -uo pipefail

PW_FILE=/tmp/.umbra-pw
sudo_run() {
  if [[ -r "$PW_FILE" ]]; then
    sudo -S -p '' "$@" < "$PW_FILE"
  else
    sudo -n "$@"
  fi
}

echo "=== 1. copy the plugin zip to the uploads directory ==="
sudo_run mkdir -p /var/www/html/wp-content/uploads
sudo_run cp /tmp/umbra-shell.zip /var/www/html/wp-content/uploads/
sudo_run chown www-data:www-data /var/www/html/wp-content/uploads/umbra-shell.zip
echo "  copied"

WP_CLI=/usr/local/bin/wp
WWW_ROOT=/var/www/html
echo
echo "=== 2. install it with wp-cli ==="
if sudo_run "$WP_CLI" plugin install \
  /var/www/html/wp-content/uploads/umbra-shell.zip \
  --activate --allow-root --path="$WWW_ROOT" 2>&1; then
  echo "  SUCCESS"
else
  echo "  FAILED"
fi

echo
echo "=== 3. check if it's there ==="
sudo_run "$WP_CLI" plugin list --allow-root --path="$WWW_ROOT" | grep umbra-shell | sed 's/^/  /'
