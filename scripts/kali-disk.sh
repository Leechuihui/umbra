#!/usr/bin/env bash
# Disk usage report for the UMBRA install test.

echo "=== filesystem ==="
df -h / | tail -1

echo
echo "=== biggest consumers in /tmp ==="
du -sh /tmp/* 2>/dev/null | sort -rh | head -10

echo
echo "=== umbra subdirs ==="
du -sh /tmp/umbra/* 2>/dev/null | sort -rh | head -10

echo
echo "=== client build artifacts ==="
du -sh /tmp/umbra/client/gui/node_modules 2>/dev/null
du -sh /tmp/umbra/client/gui/dist 2>/dev/null
du -sh /tmp/umbra/client/gui/out 2>/dev/null

echo
echo "=== cargo target ==="
du -sh /tmp/umbra/server/infra/bin/encoders/sgn/target 2>/dev/null

echo
echo "=== server venv ==="
du -sh /tmp/umbra/server/venv 2>/dev/null

echo
echo "=== inodes ==="
df -i / | tail -1
