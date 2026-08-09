#!/bin/bash
# 打包 boot.img 的脚本
# 输入: $WORKDIR/out/Image.gz-dtb 和 $WORKDIR/out/initramfs.cpio.gz
# 输出: $WORKDIR/out/boot.img

set -e

WORKDIR="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="$WORKDIR/out"

cd "$OUT_DIR"

if [ ! -f Image.gz-dtb ]; then
    echo "错误: Image.gz-dtb 不存在,请先运行 build-kernel.sh"
    exit 1
fi

if [ ! -f initramfs.cpio.gz ]; then
    echo "错误: initramfs.cpio.gz 不存在,请先构建 initramfs"
    exit 1
fi

# 红米 Note 7 (lavender) 已知参数
BASE="${BASE:-0x80000000}"
KERNEL_OFFSET="${KERNEL_OFFSET:-0x00080000}"
RAMDISK_OFFSET="${RAMDISK_OFFSET:-0x02000000}"
TAGS_OFFSET="${TAGS_OFFSET:-0x01e00000}"
PAGESIZE="${PAGESIZE:-4096}"
CMDLINE="${CMDLINE:-androidboot.console=ttyHSL0 androidboot.hardware=qcom user_debug=31 msm_rtb.filter=0x237 ehci-hcd.park=3 lpm_levels.sleep_disabled=1 cma=32M@0-0xffffffff androidboot.selinux=permissive}"

echo "==== 打包 boot.img ===="
echo "  base:           $BASE"
echo "  kernel_offset:  $KERNEL_OFFSET"
echo "  ramdisk_offset: $RAMDISK_OFFSET"
echo "  tags_offset:    $TAGS_OFFSET"
echo "  pagesize:       $PAGESIZE"
echo "  cmdline:        $CMDLINE"

mkbootimg \
    --kernel Image.gz-dtb \
    --ramdisk initramfs.cpio.gz \
    --base "$BASE" \
    --kernel_offset "$KERNEL_OFFSET" \
    --ramdisk_offset "$RAMDISK_OFFSET" \
    --tags_offset "$TAGS_OFFSET" \
    --pagesize "$PAGESIZE" \
    --cmdline "$CMDLINE" \
    --output boot.img

echo "==== boot.img 完成 ===="
ls -la boot.img
file boot.img

# 生成 SHA256SUMS
sha256sum Image.gz-dtb initramfs.cpio.gz boot.img > SHA256SUMS
echo "==== SHA256SUMS ===="
cat SHA256SUMS
