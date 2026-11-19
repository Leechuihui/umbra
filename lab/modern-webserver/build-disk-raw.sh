#!/usr/bin/env bash
# Build the 20G modern webserver disk via RAW, the only resize path that works.
#
# Why this is the reliable route:
#   - qemu-img cannot resize VDI ("Image format driver does not support resize")
#   - qemu-img CAN resize raw
#   - VirtualBox can convert raw -> VDI with convertfromraw
#   - raw is byte-for-byte, so the partition table is copied untouched and the
#     resize just appends zeros at the end of the file
#
# cloud-init's growpart module then extends the root partition into the new
# space on first boot.
#
# Earlier failures and their real causes (for the record):
#   1) genericcloud image -> ALERT! PARTUUID=... does not exist
#      That image's initramfs only ships virtio storage drivers, so the guest
#      could not see its own AHCI (SATA) disk. Fixed by using the "generic"
#      image, which carries the full driver set.
#   2) streamOptimized VMDK -> BIOS int13_harddisk error 04
#      That VMDK variant is not writable by the VM.
#   3) VBoxManage modifymedium on an attached VDI -> media registry UUID clash,
#      medium becomes "inaccessible".
#
# This script avoids all three.

set -euo pipefail

WORK=/mnt/e/vitualbox/modern-lab
SRC="$WORK/debian-12-generic-amd64.qcow2"
RAW="$WORK/webserver-modern.raw"
VDI="$WORK/webserver-modern-20g.vdi"
SEED="$WORK/seed.iso"
REPO=/mnt/c/Users/admin/Downloads/nukerat-main/nukerat-main
CI="$REPO/lab/modern-webserver/cloud-init"

cd "$WORK"

echo "=== 1. verify inputs ==="
[[ -f "$SRC" ]] || { echo "missing $SRC"; exit 1; }
[[ -f "$CI/user-data" ]] || { echo "missing user-data"; exit 1; }
[[ -f "$CI/meta-data" ]] || { echo "missing meta-data"; exit 1; }
qemu-img info "$SRC" | grep -E 'virtual size|disk size' | sed 's/^/  /'

echo
echo "=== 2. qcow2 -> raw ==="
rm -f "$RAW"
qemu-img convert -f qcow2 -O raw "$SRC" "$RAW"
ls -lh "$RAW"

echo
echo "=== 3. grow raw to 20G (appends zeros, partition table untouched) ==="
qemu-img resize -f raw "$RAW" 20G
qemu-img info "$RAW" | grep -E 'virtual size|disk size' | sed 's/^/  /'
ls -lh "$RAW"

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
echo "  raw:  $RAW (20G)"
echo "  seed: $SEED"
echo
echo "  next: VBoxManage convertfromraw \"$RAW\" \"$VDI\" --format VDI"
