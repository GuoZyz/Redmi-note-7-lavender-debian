#!/bin/bash
# 本地编译 rootfs - 第 4 步: 打包 rootfs 为 tar.gz
# 等价于 build.yml 的 "打包 rootfs"
#
# 前置: 01/02/03 步骤都已完成
# 用法: bash 04-tar-rootfs.sh

set -euo pipefail

ROOTFS="/home/GuoZy/note7-debian-local-build/rootfs"
OUT="/home/GuoZy/note7-debian-local-build/rootfs.tar.gz"
LOG="/home/GuoZy/note7-debian-local-build/logs/04-tar-rootfs.log"

if [ ! -x "$ROOTFS/bin/sh" ]; then
    echo "✗ rootfs 未初始化"
    exit 1
fi

echo "==== 步骤 4/4: 打包 rootfs.tar.gz ===="
echo "  ROOTFS = $ROOTFS"
echo "  OUT    = $OUT"
echo

# 显示最终状态
echo "==== 最终 rootfs 状态 ===="
du -sh "$ROOTFS" 2>/dev/null || true
echo
echo "  /bin:"
ls "$ROOTFS/bin/" 2>/dev/null | head -10 || true
echo "  /usr/bin (前 20):"
ls "$ROOTFS/usr/bin/" 2>/dev/null | head -20 || true
echo "  /lib/modules:"
ls "$ROOTFS/lib/modules/" 2>/dev/null || true
echo "  /boot:"
ls -la "$ROOTFS/boot/" 2>/dev/null || true
echo

# 打包 (排除不需要进入 tar 的文件)
echo "==== 打包中 (使用 gzip -1 加快速度,大小差不多) ===="
cd "$ROOTFS"
time tar --exclude='./proc/*' \
         --exclude='./sys/*' \
         --exclude='./dev/*' \
         --exclude='./run/*' \
         --exclude='./tmp/*' \
         --exclude='./var/cache/apt/archives/*.deb' \
         -czf "$OUT" \
         . 2>&1 | tee "$LOG"

echo
echo "==== 打包完成 ===="
ls -lh "$OUT"
file "$OUT"

# 验证 (列出前 30 个文件 + 验证关键文件)
echo
echo "==== 验证 (前 30 个文件) ===="
tar -tzf "$OUT" | head -30
echo
echo "  关键文件检查:"
for f in "./bin/sh" "./sbin/init" "./usr/bin/gnome-shell" "./usr/sbin/gdm3" \
         "./usr/sbin/NetworkManager" "./usr/bin/pipewire" \
         "./boot/Image.gz-dtb" "./boot/dtb" "./lib/modules"; do
    if tar -tzf "$OUT" "$f" >/dev/null 2>&1; then
        echo "  ✓ $f"
    else
        echo "  ✗ $f (缺失)"
    fi
done

echo
echo "✓ 全部完成!"
echo "  产物: $OUT"
echo
echo "==== 后续步骤 ===="
echo "  1. 把 rootfs.tar.gz 解压到 /dev/mmcblk0pXX (ext4):"
echo "       mkfs.ext4 /dev/mmcblk0pXX"
echo "       mount /dev/mmcblk0pXX /mnt"
echo "       tar -xzf rootfs.tar.gz -C /mnt"
echo "  2. 修改 /mnt/etc/fstab 中的 mmcblk0pXX 为实际分区"
echo "  3. 用 mkbootimg 重新打包 boot.img (内核+dtb+initramfs)"
echo "  4. fastboot flash boot boot.img"
