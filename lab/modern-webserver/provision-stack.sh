#!/usr/bin/env bash
# Provision the modern webserver stack on the Debian 12 lab VM.
#
# cloud-init marked itself done on the first (interrupted) boot, so the package
# and runcmd steps never completed. Running them here is deterministic and lets
# the stack be rebuilt without touching the disk image.
#
# Installs nginx, MariaDB, PHP 8.2 FPM and WordPress, then wires them together.
#
# sudo: the lab user is not the Debian cloud default user, so no NOPASSWD rule
# exists for it. vm-run.ps1 drops the password in /tmp/.umbra-pw; sudo -S reads
# it from there, which keeps the script's own stdin untouched.

set -uo pipefail

export DEBIAN_FRONTEND=noninteractive

PW_FILE=/tmp/.umbra-pw
sudo_run() {
  if [[ -r "$PW_FILE" ]]; then
    sudo -S -p '' "$@" < "$PW_FILE"
  else
    sudo -n "$@"
  fi
}

echo "=== 0. verify sudo ==="
if sudo_run true; then
  echo "  sudo works"
else
  echo "  sudo FAILED - aborting"
  exit 1
fi

echo
echo "=== 1. update package lists ==="
sudo_run apt-get update -y -qq 2>&1 | tail -3

echo
echo "=== 2. install the web stack ==="
sudo_run apt-get install -y -qq \
  nginx \
  mariadb-server \
  php8.2-fpm \
  php8.2-mysql \
  php8.2-curl \
  php8.2-gd \
  php8.2-mbstring \
  php8.2-xml \
  php8.2-zip \
  php8.2-intl \
  php8.2-bcmath \
  unzip \
  curl 2>&1 | tail -6

echo
echo "=== 3. installed versions ==="
nginx -v 2>&1 | sed 's/^/  /'
php -v 2>&1 | head -1 | sed 's/^/  /'
mariadb --version 2>&1 | head -1 | sed 's/^/  /'

echo
echo "=== 4. enable services ==="
sudo_run systemctl enable --now nginx php8.2-fpm mariadb 2>&1 | tail -3
for s in nginx mariadb php8.2-fpm; do
  echo "  $s: $(systemctl is-active "$s" 2>/dev/null || echo unknown)"
done

echo
echo "=== 5. create the WordPress database ==="
sudo_run mysql -e "
  CREATE DATABASE IF NOT EXISTS wordpress;
  CREATE USER IF NOT EXISTS 'wp_user'@'localhost' IDENTIFIED BY 'WpLab!2026';
  GRANT ALL ON wordpress.* TO 'wp_user'@'localhost';
  FLUSH PRIVILEGES;
" 2>&1 | tail -3
sudo_run mysql -e "SHOW DATABASES;" 2>&1 | grep -E 'wordpress' | sed 's/^/  /' || echo "  wordpress db not found"

echo
echo "=== 6. fetch WordPress ==="
if [[ ! -f /var/www/html/wp-config.php ]]; then
  cd /tmp || exit 1
  curl -fsSL https://wordpress.org/latest.tar.gz -o wp.tar.gz
  tar xzf wp.tar.gz
  sudo_run cp -r wordpress/. /var/www/html/
  sudo_run chown -R www-data:www-data /var/www/html
  echo "  WordPress unpacked"
else
  echo "  already present"
fi

echo
echo "=== 7. write wp-config.php ==="
if [[ ! -f /var/www/html/wp-config.php ]]; then
  sudo_run cp /var/www/html/wp-config-sample.php /var/www/html/wp-config.php
  sudo_run sed -i \
    -e "s/database_name_here/wordpress/" \
    -e "s/username_here/wp_user/" \
    -e "s/password_here/WpLab!2026/" \
    /var/www/html/wp-config.php
  sudo_run chown www-data:www-data /var/www/html/wp-config.php
  echo "  wp-config.php written"
else
  echo "  wp-config.php already present"
fi

echo
echo "=== 8. nginx vhost for PHP ==="
sudo_run tee /etc/nginx/sites-available/default > /dev/null <<'NGINX'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    root /var/www/html;
    index index.php index.html;
    server_name _;

    location / {
        try_files $uri $uri/ /index.php?$args;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.2-fpm.sock;
    }

    location ~ /\.ht {
        deny all;
    }
}
NGINX
sudo_run nginx -t 2>&1 | tail -2
sudo_run systemctl reload nginx

echo
echo "=== 9. final state ==="
for s in nginx mariadb php8.2-fpm; do
  echo "  $s: $(systemctl is-active "$s" 2>/dev/null || echo unknown)"
done
echo "  http check:"
curl -s -o /dev/null -w "    http://127.0.0.1/ -> HTTP %{http_code}\n" http://127.0.0.1/ 2>/dev/null || echo "    curl failed"

echo
echo "=== 10. done ==="
