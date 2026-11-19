#!/usr/bin/env bash
# Rebuild the disk as a plain VDI.
#
# Failure history:
#   1) qemu-img resize then convert to VDI
#        -> guest: "ALERT! PARTUUID=... does not exist"
#   2) convert to streamOptimized VMDK then VBoxManage resize
#        -> BIOS: int13_harddisk error 04 / unmapped device
#           (streamOptimized is read-only-ish; VirtualBox cannot write to it)
#
# Correct approach: convert the ORIGINAL image with no resize, to plain VDI.
# qemu-img does not touch the partition table, and plain VDI is what
# VirtualBox expects. Grow the virtual size afterwards with VBoxManage.

set -euo pipefail

WORK=/mnt/e/vitualbox/modern-lab
SRC="$WORK/debian-12-genericcloud-amd64.qcow2"
VDI="$WORK/webserver-modern.vdi"
REPO=/mnt/c/Users/admin/Downloads/nukerat-main/nukerat-main
CI="$REPO/lab/modern-webserver/cloud-init"

cd "$WORK"

echo "=== 1. verify inputs ==="
[[ -f "$SRC" ]] || { echo "missing $SRC"; exit 1; }
qemu-img info "$SRC" | grep -E 'virtual size|disk size' | sed 's/^/  /'

echo
echo "=== 2. convert qcow2 -> vdi, no resize ==="
rm -f "$VDI"
qemu-img convert -f qcow2 -O vdi "$SRC" "$VDI"
ls -lh "$VDI"
qemu-img info "$VDI" | grep -E 'virtual size|disk size' | sed 's/^/  /'

echo
echo "=== 3. rebuild the seed ISO ==="
rm -f "$WORK/seed.iso"
xorriso -as mkisofs \
  -output "$WORK/seed.iso" \
  -volid cidata \
  -joliet -rock \
  "$CI/user-data" "$CI/meta-data" 2>&1 | tail -2
ls -lh "$WORK/seed.iso"

echo
echo "=== 4. done ==="
echo "  disk: $VDI"
echo "  seed: $WORK/seed.iso"
