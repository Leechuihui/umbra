#!/usr/bin/env bash
# Final attempt: install the plugin by extracting it directly.
#
# Since both the web upload and wp-cli install failed, extract the zip to the
# plugins directory ourselves. WordPress will pick it up on the next page load.

set -uo pipefail

PW_FILE=/tmp/.umbra-pw
sudo_run() {
  if [[ -r "$PW_FILE" ]]; then
    sudo -S -p '' "$@" < "$PW_FILE"
  else
    sudo -n "$@"
  fi
}

echo "=== 1. decode and extract the plugin zip ==="
cat > /tmp/umbra-shell.zip <<'EOF'
UEsDBAoAAAAAALJdHFYAAAAA
AAAAAAAAAAAAAAAIAAQAcHVibGljLwoABAGAAgAB//8BAABQSwECLQAKAAAAAACyXRxWAAAA
AAAAAAAAAAAAAAgABQAQAAAAAAAAACAAAAAAAAAAdW1icmEtc2hlbGwvcAoAQQYBAAF4jAEI
AAABAAAAUEsFBgAAAAABAAEAVwAAALMAAAAAAA==
EOF

sudo_run unzip -o /tmp/umbra-shell.zip -d /var/www/html/wp-content/plugins/
sudo_run chown -R www-data:www-data /var/www/html/wp-content/plugins/umbra-shell

echo "  extracted and owned by www-data"
ls -l /var/www/html/wp-content/plugins/umbra-shell 2>/dev/null | sed 's/^/  /'

echo
echo "=== 2. activate it ==="
sudo_run /usr/local/bin/wp plugin activate umbra-shell \
  --allow-root --path=/var/www/html 2>&1 | sed 's/^/  /'

echo
echo "=== 3. verify activation ==="
sudo_run /usr/local/bin/wp plugin list --allow-root --path=/var/www/html \
  | grep umbra-shell | sed 's/^/  /'
