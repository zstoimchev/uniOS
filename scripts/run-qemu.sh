#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

KERNEL="/boot/vmlinuz-$(uname -r)"
INITRAMFS="$ROOT_DIR/build/initramfs.img"

if [[ ! -f "$KERNEL" ]]; then
    echo "Kernel not found: $KERNEL"
    exit 1
fi

if [[ ! -f "$INITRAMFS" ]]; then
    echo "Initramfs not found: $INITRAMFS"
    echo "Run ./scripts/build-initramfs.sh first."
    exit 1
fi

echo "Starting uniOS..."
echo "Kernel:    $KERNEL"
echo "Initramfs: $INITRAMFS"
echo

exec qemu-system-x86_64 -m 512M -kernel "$KERNEL" -initrd "$INITRAMFS" -append "console=ttyS0" -nic user,model=virtio-net-pci -nographic
