#!/usr/bin/env bash
# Rebuild the modern webserver disk from the Debian GENERIC cloud image.
#
# Root cause of the earlier boot failures:
#
#   ALERT! PARTUUID=26673c27-... does not exist. Dropping to a shell!
#
# The "genericcloud" image ships a trimmed initramfs that only carries the
# virtio storage drivers. VirtualBox exposes the disk over AHCI (SATA), so the
# guest kernel had no driver for its own root disk and could never mount it.
# Nothing was wrong with the partition table.
#
# The "generic" image keeps the full driver set, so AHCI works.
#
# This script also does the resize the safe way: convert first, then let
# VirtualBox grow the medium. qemu-img never rewrites the partition table.

set -euo pipefail

WORK=/mnt/e/vitualbox/modern-lab
SRC="$WORK/debian-12-generic-amd64.qcow2"
VDI="$WORK/webserver-modern.vdi"
SEED="$WORK/seed.iso"
REPO=/mnt/c/Users/admin/Downloads/nukerat-main/nukerat-main
CI="$REPO/lab/modern-webserver/cloud-init"

cd "$WORK"

echo "=== 1. verify inputs ==="
[[ -f "$SRC" ]] || { echo "missing $SRC"; exit 1; }
[[ -f "$CI/user-data" ]] || { echo "missing user-data"; exit 1; }
[[ -f "$CI/meta-data" ]] || { echo "missing meta-data"; exit 1; }
ls -lh "$SRC"
qemu-img info "$SRC" | grep -E 'virtual size|disk size' | sed 's/^/  /'

echo
echo "=== 2. convert qcow2 -> vdi (no resize) ==="
if [[ -f "$VDI" ]]; then
  echo "  removing previous $VDI"
  rm -f "$VDI"
fi
qemu-img convert -f qcow2 -O vdi "$SRC" "$VDI"
ls -lh "$VDI"
qemu-img info "$VDI" | grep -E 'virtual size|disk size' | sed 's/^/  /'

echo
echo "=== 3. rebuild the seed ISO ==="
rm -f "$SEED"
xorriso -as mkisofs \
  -output "$SEED" \
  -volid cidata \
  -joliet -rock \
  "$CI/user-data" "$CI/meta-data" 2>&1 | tail -2
ls -lh "$SEED"

echo
echo "=== 4. done ==="
echo "  disk: $VDI"
echo "  seed: $SEED"
echo
echo "  next: attach to a SATA controller, VBoxManage modifymedium --resize 20480, boot"
