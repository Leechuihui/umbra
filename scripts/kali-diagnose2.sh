#!/usr/bin/env bash
# Diagnose the current messy state before driving the GUI.

echo "=== 1. all umbra server processes ==="
pgrep -af 'server/main.py' 2>/dev/null || echo "none"

echo
echo "=== 2. all umbra client processes ==="
pgrep -af 'AppImage|appimage_extracted' 2>/dev/null | head -5 || echo "none"

echo
echo "=== 3. who holds port 9000 ==="
ss -ltnp 2>/dev/null | grep ':9000' || echo "free"

echo
echo "=== 4. install dirs ==="
for d in /opt/umbra /home/myroot/umbra; do
  if [[ -d "$d" ]]; then
    echo "$d  ($(du -sh "$d" 2>/dev/null | cut -f1))"
  fi
done

echo
echo "=== 5. operator keys ==="
for f in /opt/umbra/admin.key /home/myroot/umbra/admin.key; do
  if [[ -f "$f" ]]; then
    echo "$f:"
    head -1 "$f" | cut -c1-50
  else
    echo "$f: MISSING"
  fi
done

echo
echo "=== 6. client config files ==="
for f in /home/myroot/.config/umbra/config.json /root/.config/umbra/config.json; do
  if [[ -f "$f" ]]; then
    echo "$f:"
    cat "$f"
    echo
  fi
done

echo
echo "=== 7. is config valid JSON with proper shape? ==="
python3 - <<'PY'
import json, os
for p in ['/home/myroot/.config/umbra/config.json', '/root/.config/umbra/config.json']:
    if not os.path.exists(p):
        continue
    try:
        d = json.load(open(p))
    except Exception as e:
        print(f'{p}: INVALID JSON -> {e}')
        continue
    servers = d.get('servers')
    print(f'{p}:')
    print(f'  type(servers) = {type(servers).__name__}')
    if isinstance(servers, list):
        print(f'  count = {len(servers)}')
        for i, s in enumerate(servers):
            if isinstance(s, dict):
                print(f'    [{i}] dict name={s.get("name")} ip={s.get("ip")} port={s.get("port")} has_token={bool(s.get("token"))}')
            else:
                print(f'    [{i}] {type(s).__name__} = {s!r}  <-- MALFORMED')
PY
