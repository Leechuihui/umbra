#!/usr/bin/env bash
# Rebuild the modern webserver disk cleanly, with the resize done by qemu-img
# on the VDI itself.
#
# Failure history, so the next person does not repeat it:
#
#   1) genericcloud image, qemu-img resize on the qcow2 then convert to VDI
#        guest: ALERT! PARTUUID=... does not exist
#        cause: the genericcloud initramfs only carries virtio storage drivers,
#               so the guest kernel could not see its own AHCI (SATA) disk.
#               The partition table was fine all along.
#
#   2) genericcloud image, streamOptimized VMDK then VBoxManage resize
#        BIOS: int13_harddisk error 04 / unmapped device
#        cause: streamOptimized VMDK is not meant to be written by the VM.
#
#   3) Debian "generic" image (full driver set), plain VDI, no resize
#        never reached: VBoxManage modifymedium refused with a media-registry
#        UUID mismatch, leaving the medium "inaccessible".
#
# This script uses a fresh filename so no stale registry entry can collide,
# and grows the disk with qemu-img, which does not touch the partition table.
# cloud-init's growpart module then expands the root filesystem on first boot.

set -euo pipefail

WORK=/mnt/e/vitualbox/modern-lab
SRC="$WORK/debian-12-generic-amd64.qcow2"
VDI="$WORK/webserver-modern-20g.vdi"
SEED="$WORK/seed.iso"
REPO=/mnt/c/Users/admin/Downloads/nukerat-main/nukerat-main
CI="$REPO/lab/modern-webserver/cloud-init"

cd "$WORK"

echo "=== 1. verify inputs ==="
[[ -f "$SRC" ]] || { echo "missing $SRC"; exit 1; }
[[ -f "$CI/user-data" ]] || { echo "missing user-data"; exit 1; }
ls -lh "$SRC"
qemu-img info "$SRC" | grep -E 'virtual size|disk size' | sed 's/^/  /'

echo
echo "=== 2. convert to a fresh VDI ==="
rm -f "$VDI"
qemu-img convert -f qcow2 -O vdi "$SRC" "$VDI"
qemu-img info "$VDI" | grep -E 'virtual size|disk size' | sed 's/^/  /'

echo
echo "=== 3. grow the VDI to 20G with qemu-img ==="
# Resizing the container only; the partition table is untouched. cloud-init
# runs growpart on boot to extend the root partition into the new space.
qemu-img resize "$VDI" 20G
qemu-img info "$VDI" | grep -E 'virtual size|disk size' | sed 's/^/  /'
ls -lh "$VDI"

echo
echo "=== 4. rebuild the seed ISO ==="
rm -f "$SEED"
xorriso -as mkisofs \
  -output "$SEED" \
  -volid cidata \
  -joliet -rock \
  "$CI/user-data" "$CI/meta-data" 2>&1 | tail -2
ls -lh "$SEED"

echo
echo "=== 5. done ==="
echo "  disk: $VDI (20G virtual, 3G partition to be grown by cloud-init)"
echo "  seed: $SEED"
