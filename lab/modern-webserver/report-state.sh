#!/usr/bin/env bash
# Report the final state of the modern webserver lab VM.
#
# This is the "what did I actually build" summary: versions, users, plugins,
# services, and the attack surface a student would see.

set -uo pipefail

PW_FILE=/tmp/.umbra-pw
sudo_run() {
  if [[ -r "$PW_FILE" ]]; then
    sudo -S -p '' "$@" < "$PW_FILE"
  else
    sudo -n "$@"
  fi
}

echo "=============================================================="
echo " UMBRA Modern Webserver Lab - final state"
echo "=============================================================="

echo
echo "=== 1. operating system ==="
. /etc/os-release 2>/dev/null || true
echo "  distro:  ${PRETTY_NAME:-unknown}"
echo "  kernel:  $(uname -r)"
echo "  arch:    $(uname -m)"
echo "  host:    $(hostname)"

echo
echo "=== 2. network ==="
ip -4 addr show | grep -E '^[0-9]+:|inet ' | grep -v '127.0.0.1' | sed 's/^/  /'

echo
echo "=== 3. services ==="
for s in nginx mariadb php8.2-fpm ssh; do
  printf '  %-14s %s\n' "$s" "$(systemctl is-active "$s" 2>/dev/null || echo unknown)"
done

echo
echo "=== 4. versions ==="
nginx -v 2>&1 | sed 's/^/  /'
php -v 2>&1 | head -1 | sed 's/^/  /'
mariadb --version 2>&1 | head -1 | sed 's/^/  /'
sudo_run wp core version --allow-root --path=/var/www/html 2>/dev/null | sed 's/^/  wordpress /'

echo
echo "=== 5. wordpress users ==="
sudo_run wp user list --allow-root --path=/var/www/html 2>/dev/null | sed 's/^/  /'

echo
echo "=== 6. wordpress plugins ==="
sudo_run wp plugin list --allow-root --path=/var/www/html 2>/dev/null | sed 's/^/  /'

echo
echo "=== 7. listening ports ==="
sudo_run ss -tulpn 2>/dev/null | grep LISTEN | awk '{print "  "$1" "$5}' | head -12

echo
echo "=== 8. database ==="
sudo_run mysql -e "SHOW DATABASES;" 2>/dev/null | sed 's/^/  /'
echo "  --- wordpress tables ---"
sudo_run mysql -e "USE wordpress; SHOW TABLES;" 2>/dev/null | head -8 | sed 's/^/  /'

echo
echo "=== 9. web root ==="
ls -la /var/www/html 2>/dev/null | head -8 | sed 's/^/  /'

echo
echo "=== 10. credentials in wp-config.php (the exercise target) ==="
sudo_run grep -E "DB_NAME|DB_USER|DB_PASSWORD|DB_HOST" /var/www/html/wp-config.php 2>/dev/null | sed 's/^/  /'

echo
echo "=== 11. disk ==="
df -h / | tail -1 | sed 's/^/  /'

echo
echo "=============================================================="
echo " Attack surface for the exercise"
echo "=============================================================="
echo "  http://192.168.1.51/            WordPress front page"
echo "  http://192.168.1.51/wp-login.php  login form"
echo "  http://192.168.1.51/wp-json/      REST API (user enumeration)"
echo "  http://192.168.1.51/xmlrpc.php    XML-RPC (brute force target)"
echo "  ssh 192.168.1.51                  password auth enabled"
echo
echo "  Known accounts:"
echo "    admin  / Adm1n!Lab2026     (administrator)"
echo "    editor / Ed1tor!Lab2026    (editor)"
echo "    leechuihui / LabPass123!   (sudo, SSH)"
echo
echo "  Pinned old plugin: contact-form-7 5.3.1"
