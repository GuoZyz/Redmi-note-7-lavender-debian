#!/bin/bash
# 本地构建脚本 - 适用于 aarch64 Debian 13 系统
# 功能: 编译内核 + 构建 rootfs + 打包 boot.img
# 与 GitHub Actions workflow 等价

set -e

WORKDIR="$(cd "$(dirname "$0")/.." && pwd)"
KERNEL_DIR="$WORKDIR/kernel"
ROOTFS_DIR="$WORKDIR/rootfs"
INITRD_DIR="$WORKDIR/initramfs_root"
OUT_DIR="$WORKDIR/out"

KERNEL_REPO="https://github.com/LineageOS/android_kernel_xiaomi_sdm660.git"
KERNEL_BRANCH="lineage-18.1"
KERNEL_DEFCONFIG="lavender_defconfig"
ROOTFS_DIST="trixie"
ROOTFS_ARCH="arm64"
MIRROR="https://mirrors.tuna.tsinghua.edu.cn/debian"

echo "============================================"
echo "红米 Note 7 Debian 13 本地构建"
echo "============================================"
echo "工作目录: $WORKDIR"
echo ""

mkdir -p "$KERNEL_DIR" "$ROOTFS_DIR" "$INITRD_DIR" "$OUT_DIR"

# 1. 编译内核
echo "==== [1/4] 编译内核 ===="
cd "$KERNEL_DIR"
if [ ! -d .git ]; then
    git clone --depth=1 -b "$KERNEL_BRANCH" "$KERNEL_REPO" .
fi
make ARCH=arm64 "$KERNEL_DEFCONFIG"
# 启用 Debian 必需选项
./scripts/config --enable CONFIG_DEVTMPFS CONFIG_DEVTMPFS_MOUNT CONFIG_TMPFS \
                  CONFIG_CGROUPS CONFIG_SYSVIPC CONFIG_PROC_FS CONFIG_SYSFS \
                  CONFIG_FHANDLE CONFIG_EXT4_FS CONFIG_OVERLAY_FS CONFIG_DRM
make ARCH=arm64 olddefconfig
make -j$(nproc) ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- Image.gz-dtb dtbs
cp arch/arm64/boot/Image.gz-dtb "$OUT_DIR/"

# 2. 构建 rootfs
echo "==== [2/4] 构建 rootfs ===="
if [ ! -d "$ROOTFS_DIR/bin" ]; then
    sudo debootstrap --arch="$ROOTFS_ARCH" --variant=minbase \
        "$ROOTFS_DIST" "$ROOTFS_DIR" "$MIRROR"
fi

# 3. chroot 安装 GNOME
echo "==== [3/4] chroot 安装 GNOME (跳过,留给 GH Actions) ===="

# 4. 打包
echo "==== [4/4] 打包 ===="
cd "$OUT_DIR"
# initramfs 已经在 actions/ 中构建,这里直接复用
[ -f "$WORKDIR/initramfs.cpio.gz" ] && cp "$WORKDIR/initramfs.cpio.gz" .
mkbootimg \
    --kernel Image.gz-dtb \
    --ramdisk initramfs.cpio.gz \
    --base 0x80000000 \
    --kernel_offset 0x00080000 \
    --ramdisk_offset 0x02000000 \
    --tags_offset 0x01e00000 \
    --pagesize 4096 \
    --cmdline "androidboot.console=ttyHSL0 androidboot.hardware=qcom user_debug=31 msm_rtb.filter=0x237 ehci-hcd.park=3 lpm_levels.sleep_disabled=1 cma=32M@0-0xffffffff androidboot.selinux=permissive" \
    --output boot.img

sha256sum Image.gz-dtb initramfs.cpio.gz boot.img > SHA256SUMS
ls -la "$OUT_DIR"
echo ""
echo "==== 构建完成 ===="
echo "产物在: $OUT_DIR"
