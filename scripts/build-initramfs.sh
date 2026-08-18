#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

BUILD_DIR="$ROOT_DIR/build"
ROOTFS_DIR="$BUILD_DIR/rootfs"
SOURCE_ROOTFS="$ROOT_DIR/rootfs"
INSTALLER_BIN="$ROOT_DIR/target/x86_64-unknown-linux-musl/release/uniOS"

rm -rf "$ROOTFS_DIR"

mkdir -p "$ROOTFS_DIR"/{bin,dev,proc,sys,tmp}

cp "$SOURCE_ROOTFS/init" "$ROOTFS_DIR/init"

cp /usr/bin/busybox "$ROOTFS_DIR/bin/busybox"

sudo chroot "$ROOTFS_DIR" /bin/busybox --install -s /bin

cargo build --manifest-path "$ROOT_DIR/Cargo.toml" --release --target x86_64-unknown-linux-musl

cp "$INSTALLER_BIN" "$ROOTFS_DIR/bin/installer"

(
  cd "$ROOTFS_DIR"
  find . -print0 | cpio --null -ov --format=newc | gzip -9 > "$BUILD_DIR/initramfs.img"
)

