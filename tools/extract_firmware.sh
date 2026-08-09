#!/bin/bash
# 从 Android system.img 或 vendor.img 提取固件到 Debian rootfs
# 用法:
#   1. 把 system.img / vendor.img 放到 tools/ 目录
#   2. 编辑下面的 ROOTFS 变量指向你的 rootfs
#   3. 运行 ./tools/extract_firmware.sh

set -e

WORKDIR="$(cd "$(dirname "$0")/.." && pwd)"
TOOLS_DIR="$WORKDIR/tools"
ROOTFS="${ROOTFS:-$WORKDIR/rootfs}"
SYSTEM_IMG="$TOOLS_DIR/system.img"
VENDOR_IMG="$TOOLS_DIR/vendor.img"

if [ ! -d "$ROOTFS" ]; then
    echo "错误: ROOTFS 不存在: $ROOTFS"
    echo "  请先 debootstrap,或设 ROOTFS 环境变量"
    exit 1
fi

echo "==== 从 Android 镜像提取固件到 $ROOTFS/lib/firmware ===="
mkdir -p "$ROOTFS/lib/firmware"

for IMG in "$SYSTEM_IMG" "$VENDOR_IMG"; do
    if [ -f "$IMG" ]; then
        IMG_NAME=$(basename "$IMG")
        echo "==== 处理 $IMG_NAME ===="
        # 挂载为只读
        MOUNT_DIR="/tmp/mount_$$"
        sudo mkdir -p "$MOUNT_DIR"
        sudo mount -o ro,loop "$IMG" "$MOUNT_DIR" 2>/dev/null || {
            echo "  ⚠️ 无法挂载 $IMG_NAME(可能是 sparse 格式,需要 simg2img)"
            echo "  尝试用 7z 解包..."
            if command -v 7z >/dev/null; then
                cd "$MOUNT_DIR"
                sudo 7z x "$IMG" 2>/dev/null || true
                cd "$WORKDIR"
            fi
        }

        if mountpoint -q "$MOUNT_DIR"; then
            # 查找固件目录
            for fw_dir in "$MOUNT_DIR"/vendor/firmware "$MOUNT_DIR"/system/etc/firmware \
                          "$MOUNT_DIR"/firmware "$MOUNT_DIR"/vendor/firmware_mnt; do
                if [ -d "$fw_dir" ]; then
                    echo "  复制 $fw_dir -> $ROOTFS/lib/firmware/"
                    sudo cp -r "$fw_dir"/* "$ROOTFS/lib/firmware/" 2>/dev/null || true
                fi
            done
            # 复制 wifi/bt firmware (常见位置)
            for fw in /vendor/etc/wifi/WCN*.bin /vendor/etc/wifi/WCN*.dat \
                      /vendor/firmware/wlan/prima/WCNSS*; do
                if [ -f "$MOUNT_DIR$fw" ]; then
                    sudo mkdir -p "$ROOTFS/lib/firmware/wlan" 2>/dev/null
                    sudo cp "$MOUNT_DIR$fw" "$ROOTFS/lib/firmware/wlan/" 2>/dev/null || true
                fi
            done
            sudo umount "$MOUNT_DIR"
        fi
        sudo rmdir "$MOUNT_DIR" 2>/dev/null || true
    else
        echo "==== $IMG 不存在,跳过 ===="
    fi
done

echo "==== 已提取的固件: ===="
find "$ROOTFS/lib/firmware" -type f | head -30
echo "(共 $(find "$ROOTFS/lib/firmware" -type f | wc -l) 个文件)"
