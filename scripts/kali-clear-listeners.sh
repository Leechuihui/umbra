#!/usr/bin/env bash
# Remove every existing listener so the GUI test starts from a clean slate.

set -uo pipefail

ROOT=/home/myroot/umbra
BASE=http://127.0.0.1:9000

KEY=$(head -1 "$ROOT/admin.key")
U="${KEY%%:*}"; R="${KEY#*:}"; P="${R%%:*}"; S="${R#*:}"

TOKEN=$(curl -s -X POST "$BASE/auth/login" \
  -H 'Content-Type: application/json' \
  -d "{\"user\":\"$U\",\"pass\":\"$P\",\"secret\":\"$S\"}" 2>/dev/null \
  | python3 -c 'import json,sys; print(json.load(sys.stdin).get("access_token") or "")' 2>/dev/null)

if [[ -z "$TOKEN" ]]; then
  echo "login failed"
  exit 1
fi

echo "=== current listeners ==="
LIST=$(curl -s "$BASE/api/listeners/" -H "Authorization: Bearer $TOKEN" 2>/dev/null)
echo "$LIST" | head -c 400
echo

TAGS=$(echo "$LIST" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
items = d.get("active_channels") or d.get("listeners") or []
for it in items:
    tag = it.get("tag") or it.get("name")
    if tag:
        print(tag)
' 2>/dev/null)

if [[ -z "$TAGS" ]]; then
  echo "no listeners to remove"
else
  while IFS= read -r tag; do
    [[ -z "$tag" ]] && continue
    code=$(curl -s -o /dev/null -w '%{http_code}' -X DELETE "$BASE/api/listeners/$tag" \
      -H "Authorization: Bearer $TOKEN" 2>/dev/null)
    echo "  removed $tag -> HTTP $code"
  done <<< "$TAGS"
fi

sleep 2

echo
echo "=== after cleanup ==="
curl -s "$BASE/api/listeners/" -H "Authorization: Bearer $TOKEN" 2>/dev/null | head -c 300
echo
echo "=== ports ==="
ss -ltn 2>/dev/null | grep -E ':9000|:8080' || echo "  only 9000 expected"
