#!/usr/bin/env bash
# Build the modern webserver lab disk.
#
# Steps:
#   1. grow the cloud image to 20G
#   2. pack the cloud-init files into a NoCloud seed ISO
#   3. convert qcow2 -> vdi so VirtualBox can use it
#
# Everything lands in /mnt/e/vitualbox/modern-lab so it survives reboots and
# stays next to the other VirtualBox disks.

set -euo pipefail

WORK=/mnt/e/vitualbox/modern-lab
SRC="$WORK/debian-12-genericcloud-amd64.qcow2"
GROWN="$WORK/debian-12-grown.qcow2"
VDI="$WORK/webserver-modern.vdi"
SEED="$WORK/seed.iso"

# cloud-init sources come from the repo checkout.
REPO=/mnt/c/Users/admin/Downloads/nukerat-main/nukerat-main
CI="$REPO/lab/modern-webserver/cloud-init"

cd "$WORK"

echo "=== 1. verify inputs ==="
[[ -f "$SRC" ]] || { echo "missing $SRC"; exit 1; }
[[ -f "$CI/user-data" ]] || { echo "missing $CI/user-data"; exit 1; }
[[ -f "$CI/meta-data" ]] || { echo "missing $CI/meta-data"; exit 1; }
ls -lh "$SRC"
echo "  user-data: $(wc -l < "$CI/user-data") lines"

echo
echo "=== 2. grow the image to 20G ==="
if [[ -f "$GROWN" ]]; then
  echo "  removing previous $GROWN"
  rm -f "$GROWN"
fi
cp "$SRC" "$GROWN"
qemu-img resize "$GROWN" 20G
qemu-img info "$GROWN" | grep -E 'virtual size|disk size' | sed 's/^/  /'

echo
echo "=== 3. build the NoCloud seed ISO ==="
rm -f "$SEED"
# xorriso needs the files at the root, named user-data and meta-data, with
# volume id "cidata" so cloud-init recognises the NoCloud datasource.
xorriso -as mkisofs \
  -output "$SEED" \
  -volid cidata \
  -joliet -rock \
  "$CI/user-data" "$CI/meta-data" 2>&1 | tail -3
ls -lh "$SEED"

echo
echo "=== 4. convert to VDI ==="
if [[ -f "$VDI" ]]; then
  echo "  removing previous $VDI"
  rm -f "$VDI"
fi
qemu-img convert -f qcow2 -O vdi "$GROWN" "$VDI"
qemu-img info "$VDI" | grep -E 'virtual size|disk size' | sed 's/^/  /'
ls -lh "$VDI"

echo
echo "=== 5. summary ==="
echo "  disk: $VDI"
echo "  seed: $SEED"
echo
echo "  next: create the VirtualBox VM pointing at these two files"
