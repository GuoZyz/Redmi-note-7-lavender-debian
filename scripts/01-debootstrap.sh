#!/bin/bash
# 本地编译 rootfs - 第 1 步: debootstrap Debian 13 trixie ARM64 minbase
# 等价于 build.yml 的 "debootstrap Debian 13 (trixie) ARM64" 步骤
#
# 用法: sudo bash 01-debootstrap.sh [mirror]
# 默认 mirror: https://mirrors.tuna.tsinghua.edu.cn/debian

set -euo pipefail

ROOTFS="/home/GuoZy/note7-debian-local-build/rootfs"
DIST="trixie"
ARCH="arm64"
MIRROR="${1:-https://mirrors.tuna.tsinghua.edu.cn/debian}"
LOG="/home/GuoZy/note7-debian-local-build/logs/01-debootstrap.log"

echo "==== 步骤 1/3: debootstrap $DIST $ARCH ===="
echo "  ROOTFS  = $ROOTFS"
echo "  MIRROR  = $MIRROR"
echo "  LOG     = $LOG"
echo

# 检查工具
for cmd in debootstrap qemu-aarch64-static; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "✗ 缺少工具: $cmd"
        echo "  请先: apt-get install -y debootstrap qemu-user-static"
        exit 1
    fi
done

# 如果已经存在,跳过
if [ -d "$ROOTFS" ] && [ -x "$ROOTFS/bin/sh" ]; then
    echo "✓ rootfs 已存在,跳过 debootstrap"
    echo "  如需重新生成,请先删除: rm -rf $ROOTFS"
    ls -la "$ROOTFS/"
    du -sh "$ROOTFS/"
    exit 0
fi

# 清空旧目录
rm -rf "$ROOTFS"
mkdir -p "$ROOTFS"

# debootstrap
# 主机是 aarch64,仍然需要 --foreign 走 qemu 路径以便模拟 ARM64 用户态
# 但实际上 native aarch64 上 --foreign 是 no-op,直接走正常路径即可
echo "==== 运行 debootstrap (约 5-15 分钟,取决于网络) ===="
time debootstrap \
    --arch="$ARCH" \
    --variant=minbase \
    "$DIST" \
    "$ROOTFS" \
    "$MIRROR" 2>&1 | tee "$LOG" | tail -30

echo
echo "==== debootstrap 完成 ===="
ls -la "$ROOTFS/"
du -sh "$ROOTFS/"
echo
echo "✓ 第 1 步完成,运行第 2 步: bash 02-configure-rootfs.sh"
