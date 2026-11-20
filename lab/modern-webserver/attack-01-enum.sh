#!/usr/bin/env bash
# Step 1 of the demo: enumerate the WordPress target from Kali.
#
# Runs wpscan without the API token (the free mode still reports versions,
# users and plugin versions), plus a few manual checks that do not need a
# token at all.

set -uo pipefail

TARGET=192.168.1.51
BASE="http://$TARGET"
OUT=/tmp/wpscan-out

mkdir -p "$OUT"

echo "=== 1. manual fingerprint ==="
echo "  --- headers ---"
curl -s -I --max-time 8 "$BASE/" 2>/dev/null | grep -iE 'server|x-powered|link' | sed 's/^/    /'

echo "  --- generator meta ---"
curl -s --max-time 8 "$BASE/" 2>/dev/null | grep -oP '(?<=<meta name="generator" content=")[^"]*' | head -1 | sed 's/^/    /'

echo "  --- readme.html version hint ---"
curl -s --max-time 8 "$BASE/readme.html" 2>/dev/null | grep -oP '(?<=<h1 id="logo">)[^<]*' | head -1 | sed 's/^/    /'

echo
echo "=== 2. user enumeration via REST API ==="
curl -s --max-time 10 "$BASE/wp-json/wp/v2/users" 2>/dev/null \
  | python3 -c '
import json, sys
try:
    users = json.load(sys.stdin)
except Exception:
    print("    (no JSON returned)")
    raise SystemExit(0)
if not isinstance(users, list):
    print("    (unexpected shape)")
    raise SystemExit(0)
for u in users:
    print("    id={} slug={} name={}".format(u.get("id"), u.get("slug"), u.get("name")))
' 2>/dev/null

echo
echo "=== 3. xmlrpc reachable? ==="
code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 8 -X POST \
  -H 'Content-Type: text/xml' \
  --data '<?xml version="1.0"?><methodCall><methodName>system.listMethods</methodName><params></params></methodCall>' \
  "$BASE/xmlrpc.php" 2>/dev/null || echo 000)
echo "    POST /xmlrpc.php -> HTTP $code"

echo
echo "=== 4. plugin directory listing ==="
for p in contact-form-7 akismet hello; do
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 6 "$BASE/wp-content/plugins/$p/readme.txt" 2>/dev/null || echo 000)
  printf '    %-18s readme.txt HTTP %s\n' "$p" "$code"
done

echo
echo "=== 5. contact-form-7 version from readme ==="
curl -s --max-time 8 "$BASE/wp-content/plugins/contact-form-7/readme.txt" 2>/dev/null \
  | grep -iE '^Stable tag|^Version' | head -2 | sed 's/^/    /'

echo
echo "=== 6. wpscan (no api token) ==="
if command -v wpscan >/dev/null 2>&1; then
  wpscan --url "$BASE" --no-banner --random-user-agent \
    --enumerate vp,u --plugins-detection mixed \
    --disable-tls-checks 2>&1 | tee "$OUT/wpscan.txt" | grep -vE '^\s*$' | head -60
else
  echo "  wpscan not installed"
fi

echo
echo "=== 7. summary file ==="
echo "  full output: $OUT/wpscan.txt"
