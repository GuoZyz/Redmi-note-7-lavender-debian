# 红米 Note 7 (lavender / sdm660) Debian 13 + GNOME 移植项目

> ⚠️ **重要警告**: 这是一个高风险实验项目。在真机刷入 boot.img 之前,请:
> 1. 备份原 boot.img:`adb shell dd if=/dev/block/bootdevice/by-name/boot of=/sdcard/boot_stock.img`
> 2. 备份 userdata / internal storage
> 3. 确保已解锁 bootloader (OEM unlocking + fastboot unlock)
> 4. 准备 TWRP 救砖
>
> **刷机失败变砖不归本项目负责**

## 项目状态

- ✅ GitHub Actions 工作流已配置(完整 pipeline)
- ✅ 内核配置: LineageOS sdm660 lineage-18.1 + Debian 必需选项
- ✅ rootfs: Debian 13 trixie ARM64 minbase + GNOME
- ✅ boot.img: mkbootimg 标准 AOSP 格式
- ⚠️ **未在真机验证**: 显示/触屏/Modem/WiFi/音频 等功能可能需要额外适配

## 快速开始

### 1. 推送到 GitHub

```bash
cd ~/note7-debian/actions/note7-debian-gh
# 创建 GitHub 仓库(网页端),然后:
git init
git add .
git commit -m "Initial: Note7 Debian 13 build pipeline"
git branch -M main
git remote add origin git@github.com:你的用户名/note7-debian.git
git push -u origin main
```

### 2. 触发构建

进入 GitHub 仓库的 Actions 页 -> 选中 "Build Note7 Debian 13 (lavender)" -> Run workflow

构建时长: 30-90 分钟 (取决于 runner 负载)
成功后 Artifacts 下载链接:
- `note7-debian-build`: boot.img, Image.gz-dtb, rootfs.tar.gz, SHA256SUMS
- `note7-debian-release`: 完整发布包

### 3. 准备设备

```bash
# 0. 解锁 bootloader (OEM 解锁 + 等待 7 天/72 小时)
fastboot oem unlock

# 1. 备份原 boot.img
adb shell su -c 'dd if=/dev/block/bootdevice/by-name/boot of=/sdcard/boot_stock.img'
adb pull /sdcard/boot_stock.img

# 2. 确认 TWRP 已刷(用于救砖)

# 3. 查看当前分区表
adb shell cat /proc/partitions
# 找到 userdata 分区号(用于 fstab),通常:
#   mmcblk0p77 (在 LineageOS ROM 中)
#   mmcblk0p78 (在某些 ROM 中)
```

### 4. 刷入

#### 方案 A: 把 rootfs 写到 userdata 分区(最简单)

```bash
# ⚠️ 这会清空 userdata,务必备份!
adb push rootfs.tar.gz /sdcard/
adb shell su -c 'mount -o rw /dev/block/bootdevice/by-name/userdata /data'
adb shell su -c 'tar -xzf /sdcard/rootfs.tar.gz -C /data'  # 注意: 这是错的,需要解压到目标
```

> ⚠️ 上面 tar 解压写法不对。正确做法:用 fastboot boot 临时进入 Linux 来 dd。

**更安全方案**:

```bash
# 在 fastboot 模式下刷入 boot.img
fastboot flash boot boot.img

# 把 rootfs 写到 userdata 分区
# 警告: 这会清空 Android 的 /data!备份再操作!
fastboot reboot-bootloader
# 找到 userdata 分区名
fastboot getvar partition-type:userdata
# 删除 userdata 然后写 rootfs(先格式化)
fastboot format userdata    # 不推荐,这是 Android 格式
# 推荐: 通过 fastboot boot 临时进入 recovery,然后 dd
```

#### 方案 B: 用 fastboot boot 临时启动,然后从 recovery 操作

```bash
# 临时启动,看能否正常显示 (不修改任何东西)
fastboot boot boot.img
# 如果能正常显示 GNOME 或控制台,就继续方案 C
```

#### 方案 C: 写到 SD 卡或 USB(更稳)

如果有 SD 卡:
```bash
# 把 rootfs 写到 SD 卡的 ext4 分区
# 用 parted/fdisk 创建 ext4 分区
# 然后修改 fstab 中的 root 为 /dev/mmcblk1p1 (SD 卡)
```

## 故障排查

### 内核启动后无显示

可能原因:
1. cmdline 不对 -> 编辑 `scripts/build-kernel.sh` 调整 cmdline
2. display panel 驱动没编入 -> 检查 `kernel/arch/arm64/configs/lavender_defconfig` 中的 `CONFIG_FB_MSM` / `CONFIG_DRM_MSM`
3. DTB 不匹配 -> 从原 boot.img 解出正确的 DTB,替换

### 内核启动但找不到 rootfs

检查 `initramfs_root/init` 中挂载分区的逻辑:
- 默认尝试 `mmcblk0p77, p78, p79, p80, p76`
- 在 bootloader 串口或 ADB logcat 查看实际分区号
- 修改 `init` 脚本并重新打包

### GNOME 启动不了

检查 gdm 日志:
```
chroot /newroot
journalctl -u gdm3 -b
```
可能原因:
- systemd 启动顺序问题
- 用户 note7 没创建
- 没有 GPU 驱动(纯软件渲染)

## 工作流变量说明

`build.yml` 顶部的 env 变量可调整:
- `KERNEL_REPO`: 内核源
- `KERNEL_BRANCH`: 分支
- `KERNEL_DEFCONFIG`: defconfig 文件名
- `ROOTFS_DIST`: trixie
- `ROOTFS_ARCH`: arm64
- `MIRROR`: Debian 镜像源

## 重要: 需要用户填写的参数

### fstab 中的 root 分区号

`initramfs_root/init` 中默认尝试这些 mmcblk0p 分区:
- p77 (LineageOS userdata)
- p78, p79, p80 (扩展)
- p76 (vendor 之前的最后分区)

如果你的设备分区不同,请修改 `init` 脚本中的 for 循环。

### boot 参数 (cmdline)

`build.yml` 中 cmdline 基于 LineageOS 实测。如果启动失败可调整:
- `androidboot.console=ttyHSL0`
- `lpm_levels.sleep_disabled=1`
- `cma=32M@0-0xffffffff`

### 内核编译开关

`.config` 调整在 workflow `调整内核配置` 步骤。可加:
- `CONFIG_SOUND=y` (音频)
- `CONFIG_INPUT_EVDEV=y` (输入设备)
- `CONFIG_USB_EHCI_HCD=y` (USB)
- `CONFIG_TMPFS=y` (临时文件系统)

## 文件结构

```
note7-debian-gh/
├── .github/workflows/build.yml    # 主工作流
├── configs/
│   └── lavender.config            # 编译后的内核配置 (CI 生成)
├── initramfs/
│   ├── init                       # 启动脚本 (同 actions/initramfs_root/init)
│   └── etc/                       # 占位
├── scripts/
│   ├── build-kernel.sh            # 本地编译内核
│   ├── build-rootfs.sh            # 本地构建 rootfs
│   ├── package-bootimg.sh         # 打包 boot.img
│   └── local-build.sh             # 一键本地构建
├── out/                           # 构建产物 (CI 生成)
└── README.md
```

## 下一步优化方向

- [ ] 内核配置调整 (声音、Modem、电池、相机)
- [ ] device tree 提取/编译 (从原 boot.img)
- [ ] GNOME 优化 (触屏手势、屏幕旋转、电源管理)
- [ ] Phosh (手机壳)替代 GNOME
- [ ] 自动从 Android 内核合并安全补丁

## 许可

本项目中的:
- 内核源码: GPLv2 (沿用 Linux)
- rootfs 脚本: MIT
- 工作流: MIT
