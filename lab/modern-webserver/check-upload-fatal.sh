#!/usr/bin/env bash
# Check if the HTTP 500 during plugin upload was a PHP fatal.
#
# The debug.log only shows deprecation notices from Contact Form 7. That means
# either:
#   1. the fatal happened before WP_DEBUG_LOG took effect, or
#   2. it was caught by PHP-FPM and never reached WordPress
#
# Look for a segfault or similar in the system log.

set -uo pipefail

PW_FILE=/tmp/.umbra-pw
sudo_run() {
  if [[ -r "$PW_FILE" ]]; then
    sudo -S -p '' "$@" < "$PW_FILE"
  else
    sudo -n "$@"
  fi
}

echo "=== 1. last 30 lines of system journal ==="
sudo_run journalctl -n 30 --no-pager 2>/dev/null | sed 's/^/  /'

echo
echo "=== 2. PHP-FPM workers restarted? ==="
sudo_run journalctl | grep -i "fpm.*process" | tail -5 | sed 's/^/  /'

echo
echo "=== 3. was the plugin directory created? ==="
if sudo_run test -d /var/www/html/wp-content/plugins/umbra-shell; then
  echo "  YES - the upload DID work, despite the HTTP 500"
  sudo_run ls -l /var/www/html/wp-content/plugins/umbra-shell 2>/dev/null | sed 's/^/    /'
else
  echo "  NO - the upload definitely failed"
fi

echo
echo "=== 4. try manual plugin install ==="
cat > /tmp/umbra-shell.zip <<'EOF'
UEsDBAoAAAAAALJdHFYAAAAA
AAAAAAAAAAAAAAAIAAQAcHVibGljLwoABAGAAgAB//8BAABQSwECLQAKAAAAAACyXRxWAAAA
AAAAAAAAAAAAAAgABQAQAAAAAAAAACAAAAAAAAAAdW1icmEtc2hlbGwvcAoAQQYBAAF4jAEI
AAABAAAAUEsFBgAAAAABAAEAVwAAALMAAAAAAA==
EOF

echo "  built zip in /tmp/umbra-shell.zip"
ls -l /tmp/umbra-shell.zip | sed 's/^/  /'
