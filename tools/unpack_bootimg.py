#!/usr/bin/env python3
"""
unpack_bootimg.py - 解包 Android boot.img
基于 AOSP 的 unpack_bootimg 实现,纯 Python 版本
用于调试:确认 page size / kernel offset / ramdisk offset / cmdline 等参数

用法: python3 unpack_bootimg.py <boot.img> [输出目录]
"""
import sys
import struct
import os

def main():
    if len(sys.argv) < 2:
        print(f"用法: {sys.argv[0]} <boot.img> [输出目录]")
        sys.exit(1)

    bootimg = sys.argv[1]
    outdir = sys.argv[2] if len(sys.argv) > 2 else "bootimg_unpacked"

    if not os.path.exists(bootimg):
        print(f"错误: {bootimg} 不存在")
        sys.exit(1)

    os.makedirs(outdir, exist_ok=True)

    with open(bootimg, 'rb') as f:
        # AOSP boot image header format (v0)
        # https://source.android.com/devices/bootloader/boot-image-header
        magic = f.read(8)
        if magic != b'ANDROID!':
            print(f"错误: 不是 AOSP boot.img (magic={magic!r})")
            sys.exit(1)

        # 读取 header
        f.seek(0)
        header = f.read(0x800)  # header 至少 512 字节,通常 2048

        # 解析 v0 header
        kernel_size = struct.unpack('<I', header[0x08:0x0c])[0]
        kernel_addr = struct.unpack('<I', header[0x0c:0x10])[0]
        ramdisk_size = struct.unpack('<I', header[0x10:0x14])[0]
        ramdisk_addr = struct.unpack('<I', header[0x14:0x18])[0]
        second_size = struct.unpack('<I', header[0x18:0x1c])[0]
        second_addr = struct.unpack('<I', header[0x1c:0x20])[0]
        tags_addr = struct.unpack('<I', header[0x20:0x24])[0]
        page_size = struct.unpack('<I', header[0x24:0x28])[0]
        # 0x28-0x2b: header version, os version, etc
        name = header[0x32:0x62].rstrip(b'\x00').decode('ascii', errors='replace')
        cmdline = header[0x62:0x262].rstrip(b'\x00').decode('ascii', errors='replace')

        # 计算 offset (基于 page size)
        kernel_offset = kernel_addr - 0x80000000  # 假设 base 是 0x80000000
        ramdisk_offset = ramdisk_addr - 0x80000000

        print("==== boot.img 解析结果 ====")
        print(f"  magic:        ANDROID!")
        print(f"  page_size:    {page_size} (0x{page_size:x})")
        print(f"  kernel_size:  {kernel_size} bytes")
        print(f"  kernel_addr:  0x{kernel_addr:08x}")
        print(f"  kernel_off:   0x{kernel_offset:08x}")
        print(f"  ramdisk_size: {ramdisk_size} bytes")
        print(f"  ramdisk_addr: 0x{ramdisk_addr:08x}")
        print(f"  ramdisk_off:  0x{ramdisk_offset:08x}")
        print(f"  second_size:  {second_size} bytes")
        print(f"  second_addr:  0x{second_addr:08x}")
        print(f"  tags_addr:    0x{tags_addr:08x}")
        print(f"  name:         {name}")
        print(f"  cmdline:")
        print(f"    {cmdline}")

        # 提取 kernel 和 ramdisk
        # kernel 从 page_size 开始,ramdisk 在 kernel 后
        kernel_off_in_file = page_size
        kernel_data = f.read(kernel_size)
        with open(os.path.join(outdir, 'kernel'), 'wb') as kf:
            kf.write(kernel_data)
        print(f"  ✓ kernel 写入 {outdir}/kernel")

        # 对齐到 page size
        padding = page_size - (kernel_size % page_size) if kernel_size % page_size else 0
        f.read(padding)

        ramdisk_off_in_file = kernel_off_in_file + kernel_size + padding
        ramdisk_data = f.read(ramdisk_size)
        with open(os.path.join(outdir, 'ramdisk.cpio.gz'), 'wb') as rf:
            rf.write(ramdisk_data)
        print(f"  ✓ ramdisk 写入 {outdir}/ramdisk.cpio.gz")

        print()
        print("==== 建议的 mkbootimg 参数 ====")
        print(f"  --base 0x80000000")
        print(f"  --kernel_offset 0x{kernel_offset:08x}")
        print(f"  --ramdisk_offset 0x{ramdisk_offset:08x}")
        print(f"  --tags_offset 0x{tags_addr - 0x80000000:08x}")
        print(f"  --pagesize {page_size}")
        print(f"  --cmdline \"{cmdline}\"")

if __name__ == '__main__':
    main()
