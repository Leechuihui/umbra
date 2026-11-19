#!/usr/bin/env bash
# Probe the tooling needed to build a modern Debian VM unattended.
#
# The plan is a cloud image plus a cloud-init seed, which avoids any
# interactive installer. That needs:
#   - a way to convert qcow2 -> vdi (qemu-img)
#   - a way to build the NoCloud seed ISO (genisoimage / xorriso / cloud-localds)
#   - curl to download the image

echo "=== image conversion ==="
for t in qemu-img vboxmanage VBoxManage; do
  if command -v "$t" >/dev/null 2>&1; then
    echo "[OK] $t -> $(command -v "$t")"
  else
    echo "[--] $t"
  fi
done

echo
echo "=== ISO authoring ==="
for t in genisoimage mkisofs xorriso cloud-localds; do
  if command -v "$t" >/dev/null 2>&1; then
    echo "[OK] $t -> $(command -v "$t")"
  else
    echo "[--] $t"
  fi
done

echo
echo "=== download / checksum ==="
for t in curl wget sha256sum; do
  if command -v "$t" >/dev/null 2>&1; then
    echo "[OK] $t"
  else
    echo "[--] $t"
  fi
done

echo
echo "=== disk space in /tmp and /var/tmp ==="
df -h /tmp /var/tmp 2>/dev/null | sed 's/^/  /'

echo
echo "=== os ==="
head -2 /etc/os-release
