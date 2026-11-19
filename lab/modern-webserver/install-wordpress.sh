#!/usr/bin/env bash
# Finish the WordPress install on the modern webserver VM.
#
# nginx now serves PHP, but every request 302-redirects because WordPress has
# no tables yet: it sends visitors to /wp-admin/install.php.
#
# Rather than clicking through the web installer, this script drives the same
# steps with wp-cli, which is reproducible and leaves a known admin account.

set -uo pipefail

PW_FILE=/tmp/.umbra-pw
sudo_run() {
  if [[ -r "$PW_FILE" ]]; then
    sudo -S -p '' "$@" < "$PW_FILE"
  else
    sudo -n "$@"
  fi
}

echo "=== 1. where does / redirect to? ==="
curl -s -o /dev/null -w '  Location: %{redirect_url}\n' --max-time 8 http://127.0.0.1/ 2>/dev/null || echo "  no redirect"

echo
echo "=== 2. install wp-cli ==="
if ! command -v wp >/dev/null 2>&1; then
  curl -fsSL https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar -o /tmp/wp-cli.phar
  chmod +x /tmp/wp-cli.phar
  sudo_run mv /tmp/wp-cli.phar /usr/local/bin/wp
  echo "  installed to /usr/local/bin/wp"
else
  echo "  already installed"
fi
wp --version --allow-root 2>&1 | sed 's/^/  /'

echo
echo "=== 3. run the WordPress install ==="
cd /var/www/html || exit 1

if sudo_run wp core is-installed --allow-root 2>/dev/null; then
  echo "  already installed"
else
  sudo_run wp core install \
    --url="http://192.168.1.51" \
    --title="Ministry of Modern Pony" \
    --admin_user="admin" \
    --admin_password="Adm1n!Lab2026" \
    --admin_email="admin@lab.local" \
    --skip-email \
    --allow-root 2>&1 | tail -5 | sed 's/^/  /'
fi

echo
echo "=== 4. add a low-privilege user (useful for the exercise) ==="
if sudo_run wp user get editor --allow-root >/dev/null 2>&1; then
  echo "  editor already exists"
else
  sudo_run wp user create editor editor@lab.local \
    --role=editor \
    --user_pass="Ed1tor!Lab2026" \
    --allow-root 2>&1 | tail -3 | sed 's/^/  /'
fi

echo
echo "=== 5. install a plugin with a known-old version (exercise target) ==="
# Contact Form 7 5.3.1 has a documented unrestricted file upload issue.
# Keeping a pinned old version gives the lab a realistic finding to chase.
if sudo_run wp plugin is-installed contact-form-7 --allow-root 2>/dev/null; then
  echo "  already installed"
else
  sudo_run wp plugin install contact-form-7 --version=5.3.1 --activate --allow-root 2>&1 | tail -4 | sed 's/^/  /'
fi

echo
echo "=== 6. verify ==="
for path in / /wp-login.php /wp-admin/; do
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 8 "http://127.0.0.1$path" 2>/dev/null || echo 000)
  printf '  %-16s HTTP %s\n' "$path" "$code"
done

echo
echo "=== 7. page title ==="
curl -sL --max-time 10 http://127.0.0.1/ 2>/dev/null | grep -oP '(?<=<title>)[^<]*' | head -1 | sed 's/^/  /' || echo "  (no title)"

echo
echo "=== 8. wordpress version ==="
sudo_run wp core version --allow-root 2>/dev/null | sed 's/^/  /'

echo
echo "=== 9. plugins ==="
sudo_run wp plugin list --allow-root 2>/dev/null | sed 's/^/  /'

echo
echo "=== 10. users ==="
sudo_run wp user list --allow-root 2>/dev/null | sed 's/^/  /'
