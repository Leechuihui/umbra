#!/usr/bin/env bash
# Check whether cloud-init ran on the built disk, and inspect the filesystem.

VDI=/mnt/e/vitualbox/modern-lab/webserver-modern.vdi

echo "=== tool availability ==="
for t in guestfish virt-cat virt-ls qemu-nbd partx; do
  if command -v "$t" >/dev/null 2>&1; then
    echo "[OK] $t"
  else
    echo "[--] $t"
  fi
done

echo
echo "=== disk info ==="
qemu-img info "$VDI" 2>/dev/null | head -8

echo
echo "=== partition table ==="
if command -v virt-filesystems >/dev/null 2>&1; then
  virt-filesystems --long -h --all -a "$VDI" 2>&1 | head -20
else
  echo "  virt-filesystems not available"
fi

echo
echo "=== try guestfish inspection ==="
if command -v guestfish >/dev/null 2>&1; then
  guestfish --ro -a "$VDI" -i <<'EOF' 2>&1 | head -40
  echo "--- /etc/hostname ---"
  cat /etc/hostname 2>/dev/null || echo "(missing)"
  echo "--- /var/log/cloud-init-output.log (tail) ---"
  tail /var/log/cloud-init-output.log 2>/dev/null || echo "(missing)"
  echo "--- /var/lib/cloud ---"
  ls /var/lib/cloud 2>/dev/null || echo "(missing)"
  echo "--- /var/www/html ---"
  ls /var/www/html 2>/dev/null || echo "(missing)"
EOF
else
  echo "  guestfish not available"
fi
