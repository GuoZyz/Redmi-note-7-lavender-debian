#!/bin/bash
# 本地编译 rootfs - 第 3 步: 安装内核模块 + dtb 到 rootfs
# 等价于 build.yml 的 "复制内核模块到 rootfs" + "复制 dtb 到 rootfs"
#
# 前置:
#   - 01-debootstrap.sh 已运行
#   - 02-configure-rootfs.sh 已运行
#   - 内核已编译: /home/GuoZy/kernel-test/android_kernel_xiaomi_sdm660-lineage-18.1/arch/arm64/boot/Image.gz-dtb
# 用法: sudo bash 03-install-kernel-modules.sh

set -euo pipefail

ROOTFS="/home/GuoZy/note7-debian-local-build/rootfs"
KERNEL_SRC="/home/GuoZy/kernel-test/android_kernel_xiaomi_sdm660-lineage-18.1"
KERNEL_VER="$(cd "$KERNEL_SRC" && make kernelversion 2>/dev/null || echo 'unknown')"
LOG="/home/GuoZy/note7-debian-local-build/logs/03-install-kernel-modules.log"

# 也支持旧路径
if [ ! -d "$KERNEL_SRC" ]; then
    KERNEL_SRC="/home/GuoZy/kernel-build/android_kernel_xiaomi_sdm660-lineage-18.1"
fi

if [ ! -d "$KERNEL_SRC" ]; then
    echo "✗ 找不到内核源码目录"
    echo "  请确认内核已编译,目录包含:"
    echo "    $KERNEL_SRC/arch/arm64/boot/Image.gz-dtb"
    exit 1
fi

echo "==== 步骤 3/4: 安装内核模块 + dtb 到 rootfs ===="
echo "  KERNEL_SRC = $KERNEL_SRC"
echo "  KERNEL_VER = $KERNEL_VER"
echo "  ROOTFS     = $ROOTFS"
echo

# === 3.1 安装内核模块 ===
echo "==== [1/3] 编译并安装内核模块 ===="
cd "$KERNEL_SRC"

# 使用 INSTALL_MOD_PATH 指向 rootfs
INSTALL_MOD_PATH="$ROOTFS" \
INSTALL_MOD_STRIP=1 \
make -j"$(nproc)" \
    ARCH=arm64 \
    CROSS_COMPILE=aarch64-linux-gnu- \
    KCFLAGS="-Wno-error" \
    modules_install 2>&1 | tee "$LOG" | tail -20

echo "  模块安装目录:"
ls -la "$ROOTFS/lib/modules/" 2>/dev/null || echo "  ✗ 模块目录未生成"

# === 3.2 复制 dtb ===
echo
echo "==== [2/3] 复制 dtb 到 /boot/dtb ===="
mkdir -p "$ROOTFS/boot/dtb"
if [ -d "$KERNEL_SRC/arch/arm64/boot/dts" ]; then
    find "$KERNEL_SRC/arch/arm64/boot/dts" -name '*.dtb' \
        -exec cp -v {} "$ROOTFS/boot/dtb/" \; 2>&1 | tail -10
fi
echo "  dtb 数量: $(ls "$ROOTFS/boot/dtb/" 2>/dev/null | wc -l)"

# === 3.3 复制内核镜像 ===
echo
echo "==== [3/3] 复制内核镜像到 /boot ===="
if [ -f "$KERNEL_SRC/arch/arm64/boot/Image.gz-dtb" ]; then
    cp "$KERNEL_SRC/arch/arm64/boot/Image.gz-dtb" "$ROOTFS/boot/"
    ls -la "$ROOTFS/boot/Image.gz-dtb"
    file "$ROOTFS/boot/Image.gz-dtb"
else
    echo "✗ Image.gz-dtb 不存在,内核未编译?"
    exit 1
fi

echo
echo "==== 第 3 步完成 ===="
du -sh "$ROOTFS/"
ls -la "$ROOTFS/boot/"
echo
echo "✓ 第 3 步完成,运行第 4 步: bash 04-tar-rootfs.sh"
