#!/bin/bash
# 单独编译内核的脚本

set -e

WORKDIR="$(cd "$(dirname "$0")/.." && pwd)"
KERNEL_DIR="$WORKDIR/kernel"
OUT_DIR="$WORKDIR/out"

KERNEL_REPO="https://github.com/LineageOS/android_kernel_xiaomi_sdm660.git"
KERNEL_BRANCH="lineage-18.1"
KERNEL_DEFCONFIG="${KERNEL_DEFCONFIG:-lavender_defconfig}"

mkdir -p "$KERNEL_DIR" "$OUT_DIR"

cd "$KERNEL_DIR"
if [ ! -d .git ]; then
    echo "==== 克隆内核源码 ===="
    git clone --depth=1 -b "$KERNEL_BRANCH" "$KERNEL_REPO" .
fi

echo "==== 配置内核 ===="
make ARCH=arm64 "$KERNEL_DEFCONFIG"

# 调整 .config
echo "==== 调整 Debian 必需选项 ===="
./scripts/config --enable CONFIG_DEVTMPFS
./scripts/config --enable CONFIG_DEVTMPFS_MOUNT
./scripts/config --enable CONFIG_TMPFS
./scripts/config --enable CONFIG_TMPFS_POSIX_ACL
./scripts/config --enable CONFIG_CGROUPS
./scripts/config --enable CONFIG_SYSVIPC
./scripts/config --enable CONFIG_PROC_FS
./scripts/config --enable CONFIG_SYSFS
./scripts/config --enable CONFIG_FHANDLE
./scripts/config --enable CONFIG_EXT4_FS
./scripts/config --enable CONFIG_OVERLAY_FS
./scripts/config --enable CONFIG_DRM

make ARCH=arm64 olddefconfig

echo "==== 编译内核 ===="
make -j$(nproc) ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- Image.gz-dtb dtbs

cp arch/arm64/boot/Image.gz-dtb "$OUT_DIR/"
cp .config "$OUT_DIR/lavender.config"
echo "==== 内核编译完成 ===="
ls -la "$OUT_DIR/Image.gz-dtb"
file "$OUT_DIR/Image.gz-dtb"
