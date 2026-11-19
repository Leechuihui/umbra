#!/usr/bin/env bash
# Fix the nginx vhost on the modern webserver VM.
#
# Why the previous attempt failed:
#
#   sudo_run tee /etc/nginx/sites-available/default > /dev/null <<'NGINX'
#
#   sudo_run runs `sudo -S ... < "$PW_FILE"`, which replaces stdin with the
#   password file. `tee` therefore read the password instead of the heredoc,
#   so the config was written as a truncated fragment and nginx refused it:
#
#     [emerg] unexpected end of file, expecting ";" or "}" in .../default:2
#
# Fix: build the file in /tmp with a plain redirect (no sudo, so stdin is the
# heredoc as intended), then copy it into place with sudo.

set -uo pipefail

PW_FILE=/tmp/.umbra-pw
sudo_run() {
  if [[ -r "$PW_FILE" ]]; then
    sudo -S -p '' "$@" < "$PW_FILE"
  else
    sudo -n "$@"
  fi
}

echo "=== 1. current broken config ==="
head -5 /etc/nginx/sites-available/default 2>/dev/null | sed 's/^/  /' || echo "  (missing)"

echo
echo "=== 2. write the vhost to /tmp (no sudo, heredoc intact) ==="
cat > /tmp/umbra-nginx-default <<'NGINX'
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

echo "  wrote $(wc -l < /tmp/umbra-nginx-default) lines"
echo "  --- content ---"
sed 's/^/    /' /tmp/umbra-nginx-default

echo
echo "=== 3. install it with sudo ==="
sudo_run cp /tmp/umbra-nginx-default /etc/nginx/sites-available/default
sudo_run chmod 644 /etc/nginx/sites-available/default
echo "  installed"

echo
echo "=== 4. validate ==="
if sudo_run nginx -t 2>&1 | tail -2 | sed 's/^/  /'; then
  echo "  config OK"
else
  echo "  config still broken"
  exit 1
fi

echo
echo "=== 5. reload nginx ==="
sudo_run systemctl restart nginx
sleep 2
echo "  nginx: $(systemctl is-active nginx 2>/dev/null || echo unknown)"

echo
echo "=== 6. verify HTTP ==="
for path in / /wp-admin/ /wp-login.php; do
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 8 "http://127.0.0.1$path" 2>/dev/null || echo 000)
  printf '  %-16s HTTP %s\n' "$path" "$code"
done

echo
echo "=== 7. page title ==="
curl -s --max-time 8 http://127.0.0.1/ 2>/dev/null | grep -oP '(?<=<title>)[^<]*' | head -1 | sed 's/^/  /' || echo "  (no title)"

echo
echo "=== 8. services ==="
for s in nginx mariadb php8.2-fpm; do
  echo "  $s: $(systemctl is-active "$s" 2>/dev/null || echo unknown)"
done
