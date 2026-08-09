#!/bin/bash
# 单独构建 rootfs 的脚本(不含 GNOME 安装,只做 debootstrap)

set -e

WORKDIR="$(cd "$(dirname "$0")/.." && pwd)"
ROOTFS_DIR="$WORKDIR/rootfs"
OUT_DIR="$WORKDIR/out"

ROOTFS_DIST="${ROOTFS_DIST:-trixie}"
ROOTFS_ARCH="${ROOTFS_ARCH:-arm64}"
MIRROR="${MIRROR:-https://mirrors.tuna.tsinghua.edu.cn/debian}"

mkdir -p "$ROOTFS_DIR" "$OUT_DIR"

if [ -d "$ROOTFS_DIR/bin" ]; then
    echo "rootfs 已存在,跳过 debootstrap"
else
    echo "==== debootstrap $ROOTFS_DIST $ROOTFS_ARCH ===="
    sudo debootstrap --arch="$ROOTFS_ARCH" --variant=minbase \
        "$ROOTFS_DIST" "$ROOTFS_DIR" "$MIRROR"
fi

echo "==== 打包 rootfs.tar.gz ===="
cd "$ROOTFS_DIR"
sudo tar --numeric-owner -czf "$OUT_DIR/rootfs.tar.gz" .
ls -la "$OUT_DIR/rootfs.tar.gz"
