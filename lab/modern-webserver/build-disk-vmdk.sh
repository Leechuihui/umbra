#!/usr/bin/env bash
# Rebuild the modern webserver disk using VMDK + VirtualBox's own resize.
#
# The first attempt resized the qcow2 with qemu-img and then converted to VDI.
# The guest then failed to boot with:
#
#   ALERT! PARTUUID=26673c27-... does not exist. Dropping to a shell!
#
# The partition table did not survive that combination. This version avoids the
# problem entirely: convert the untouched image to VMDK, then let VirtualBox
# grow the virtual size. The partition table is never rewritten by qemu-img.

set -euo pipefail

WORK=/mnt/e/vitualbox/modern-lab
SRC="$WORK/debian-12-genericcloud-amd64.qcow2"
VMDK="$WORK/webserver-modern.vmdk"
SEED="$WORK/seed.iso"
REPO=/mnt/c/Users/admin/Downloads/nukerat-main/nukerat-main
CI="$REPO/lab/modern-webserver/cloud-init"

cd "$WORK"

echo "=== 1. verify inputs ==="
[[ -f "$SRC" ]] || { echo "missing $SRC"; exit 1; }
[[ -f "$CI/user-data" ]] || { echo "missing user-data"; exit 1; }
[[ -f "$CI/meta-data" ]] || { echo "missing meta-data"; exit 1; }

echo
echo "=== 2. inspect the source image partitions ==="
qemu-img info "$SRC" | grep -E 'virtual size|disk size' | sed 's/^/  /'
if command -v virt-filesystems >/dev/null 2>&1; then
  virt-filesystems --long -h --all -a "$SRC" 2>&1 | head -12 | sed 's/^/  /'
fi

echo
echo "=== 3. convert qcow2 -> vmdk (no resize here) ==="
rm -f "$VMDK"
qemu-img convert -f qcow2 -O vmdk -o subformat=streamOptimized "$SRC" "$VMDK"
ls -lh "$VMDK"
qemu-img info "$VMDK" | grep -E 'virtual size|disk size' | sed 's/^/  /'

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
echo "  disk: $VMDK"
echo "  seed: $SEED"
echo
echo "  next: VBoxManage modifymedium --resize 20480 on the vmdk,"
echo "        then attach and boot, then growpart inside the guest."
