# 红米 Note 7 (lavender / sdm660) 配置参数说明

本文档列出所有"用户可能需要根据自己设备调整"的参数。
在 GitHub Actions 工作流中,这些参数已设置为合理默认值,但用户可能需要在
构建前/构建后调整。

---

## 1. 内核编译参数

修改 `.github/workflows/build.yml` 顶部的 env:

```yaml
env:
  KERNEL_REPO: "https://github.com/LineageOS/android_kernel_xiaomi_sdm660.git"
  KERNEL_BRANCH: "lineage-18.1"
  KERNEL_DEFCONFIG: "lavender_defconfig"
```

**可能需要的替代**:
- `KERNEL_BRANCH`: `cm-14.1` (旧 CyanogenMod), `lineage-17.1` (Android 10), `lineage-18.1` (Android 11,推荐)
- `KERNEL_DEFCONFIG`: `lavender-perf_defconfig` (性能优化版),如果存在

**当前采用的**: lineage-18.1 (Android 11),因为它和 LineageOS 18.1 ROM 兼容性最好。

---

## 2. rootfs 配置

```yaml
ROOTFS_DIST: "trixie"          # Debian 13
ROOTFS_ARCH: "arm64"
MIRROR: "https://mirrors.tuna.tsinghua.edu.cn/debian"
```

**MIRROR 备选**:
- `https://mirrors.ustc.edu.cn/debian` (中科大)
- `https://mirrors.aliyun.com/debian` (阿里云)
- `https://mirrors.cloud.tencent.com/debian` (腾讯云)
- `http://deb.debian.org/debian` (Debian 官方)

---

## 3. boot.img 参数 (mkbootimg)

修改 `.github/workflows/build.yml` 的 `mkbootimg 打包` 步骤:

```bash
--base 0x80000000              # 通常 0x80000000
--kernel_offset 0x00080000     # 通常 0x00080000
--ramdisk_offset 0x02000000    # 通常 0x02000000
--tags_offset 0x01e00000       # 通常 0x01e00000
--pagesize 4096                # 大多数 sdm660 是 4096
--cmdline "androidboot.console=ttyHSL0 androidboot.hardware=qcom ..."
```

**如果启动失败,以下是需要检查的项**:

### 3.1 page size
有些设备的 boot.img 是 2048 而非 4096。可以用以下方法确认:
```bash
# 在 Android 端提取原 boot.img:
adb shell su -c 'dd if=/dev/block/bootdevice/by-name/boot of=/sdcard/boot_stock.img'
adb pull /sdcard/boot_stock.img
# 然后用 unpack_bootimg 工具(在 tools/ 中)检查 page size
```

### 3.2 cmdline
原 cmdline 可以这样获取:
```bash
adb shell cat /proc/cmdline
```
然后直接用它替换工作流中的 cmdline。

### 3.3 base / offsets
通常 sdm660 用的是:
- base: 0x80000000
- kernel_offset: 0x00080000
- ramdisk_offset: 0x02000000
- tags_offset: 0x01e00000

但不同厂商可能有差异。可以用 unpack_bootimg 反推。

---

## 4. fstab (root 分区)

修改 rootfs 中的 `/etc/fstab`:

```
/dev/mmcblk0pXX  /  ext4  defaults,noatime  0  1
```

**XX 的确定方法**:
1. 启动 recovery 或 Linux 后:`cat /proc/partitions`
2. 在 Android 中:`adb shell cat /proc/partitions` 或 `adb shell ls /dev/block/bootdevice/by-name/`
3. 通常 `userdata` 是 rootfs 候选,但具体 mmcblk0pXX 数字看设备

**lavender 已知**(基于 LineageOS 18.1):
- `mmcblk0p77` 是 userdata (32GB ROM 设备)
- `mmcblk0p78` 是 userdata (64GB ROM 设备)
- `mmcblk0p79` 是 userdata (128GB ROM 设备)

**最简单的策略**:
1. 启动到 initramfs shell(无法挂载 rootfs 时会自动进入)
2. 运行 `cat /proc/partitions`,找到大小合适的 ext4 分区
3. 写入 fstab

**在 initramfs 中已默认尝试** (按顺序):
- p77, p78, p79, p80, p76, p75, p50, p49 (mmcblk0)
- p1, p2 (mmcblk1 = SD 卡)

---

## 5. initramfs 的 init 脚本

修改 `initramfs/init`(工作流中也嵌入了),关键变量:

```sh
# 在这里加入你的分区尝试:
for p in /dev/mmcblk0p77 /dev/mmcblk0pXX ...; do
    ...
done
```

---

## 6. 用户密码

工作流中已硬编码:
- `root: 126112`
- `note7: 126112`

修改位置:
- `配置 rootfs 用户和系统设置` 步骤中的 `chpasswd` 命令
- `useradd` 创建用户的命令

**强烈建议**:在第一次成功启动后,通过 chroot 或运行 `passwd` 修改。

---

## 7. apt 源选择

修改 rootfs 中的 `/etc/apt/sources.list`,工作流中已用清华源:

```
deb https://mirrors.tuna.tsinghua.edu.cn/debian trixie main contrib non-free non-free-firmware
deb https://mirrors.tuna.tsinghua.edu.cn/debian trixie-updates main contrib non-free non-free-firmware
deb https://mirrors.tuna.tsinghua.edu.cn/debian trixie-backports main contrib non-free non-free-firmware
deb https://mirrors.tuna.tsinghua.edu.cn/debian-security trixie-security main contrib non-free non-free-firmware
```

**注意**: Debian 13 (trixie) 把 `non-free` 拆成了 `non-free` 和 `non-free-firmware`。
有些包(如某些 WiFi 固件)在 `non-free-firmware` 中。

---

## 8. GNOME 软件包列表

工作流中已安装的 GNOME 包:
- `gnome` (元包,包含所有标准 GNOME 应用)
- `gnome-shell` (GNOME Shell 主程序)
- `gdm3` (显示管理器)
- `gnome-terminal`, `nautilus`, `gnome-control-center`, `gnome-tweaks`
- `xdg-utils`, `xdg-user-dirs`

如果 GNOME 启动失败,可能的精简方案(在 chroot 中):
```bash
# 卸装不必要的 GNOME 组件
apt remove --purge evolution* cheese rhythmbox* gnome-music gnome-photos
# 切换到更轻的桌面
apt install xfce4 lightdm
```

---

## 9. 触摸/显示驱动

**这是最大的不确定性**:
- 内核的 display 驱动是 `CONFIG_DRM_MSM` (主线) 或 `CONFIG_FB_MSM` (下游)
- 默认 LineageOS sdm660 已编入 DRM_MSM
- 但 panel init 序列可能不匹配(尤其如果用 LineageOS 内核 + Debian userspace)

**如果触摸/显示不正常**:
1. 检查 `lavender_defconfig` 中是否有 `CONFIG_DRM_MSM=y`
2. 检查 `CONFIG_DRM_PANEL_SIMPLE=y` 或 panel-specific 配置
3. 启用 boot 时的详细日志:`dmesg | grep -i mdp`

---

## 10. Modem 启用

GNOME 默认不显示 Modem 状态。需要:
- `ModemManager` 已装并启用(工作流中)
- NetworkManager 配置:`/etc/NetworkManager/conf.d/`
- 检查 Modem 是否被识别:`mmcli -L`

如果 ModemManager 找不到 modem,可能需要:
```bash
# 检查 /dev/wwan*
ls /dev/wwan*
# 检查 QMI 设备
ls /dev/qcqmi*
```

---

## 11. WiFi / 蓝牙

WiFi: Qualcomm WCN3990 通常用 `ath10k_snoc` 驱动(主线)或 `cnss` + `wlan` (下游)。
蓝牙: Qualcomm BT 通过 UART 或 shared memory,需要 `btqcomsmd` 或 `btnxpuart` 等。

**主线内核情况**:
- `CONFIG_CFG80211=y`, `CONFIG_MAC80211=y`
- `CONFIG_ATH10K=y`, `CONFIG_ATH10K_SDIO=n` (sdm660 不太可能用 SDIO)

**下游内核情况**:
- 自带 `cnss` 和 `wlan` 驱动,但可能需要 firmware blob
- firmware 通常在 `/vendor/firmware/` 或 `/lib/firmware/`

**根文件系统可能需要的固件**:
```
/lib/firmware/ath10k/WCN3990/
/lib/firmware/wlan/
/lib/firmware/qca/
```

这些通常在原 boot.img 的 ramdisk 或 system 分区中。

**工作流暂未处理**: 固件提取。这是真机刷机时需要补充的。

---

## 12. 已知未实现/未优化项

- ❌ 固件提取(从原 boot.img / system.img)
- ❌ 屏幕旋转(可能需要额外配置)
- ❌ 电池百分比显示
- ❌ 触屏校准
- ❌ 声音路由
- ❌ 相机
- ❌ GNSS / GPS
- ❌ NFC
- ❌ 指纹

这些都需要额外适配,不是简单脚本能解决的。

---

## 13. 调试技巧

### 13.1 通过串口调试

如果 Note 7 有 UART 接口(开发板版本),可以接 USB-TTL 看完整 boot log。
普通量产版本没有暴露的 UART,需要:
1. ADB logcat (需要 Android 已启动或 recovery 模式)
2. 启用 kernel printk:`dmesg` 查看内核日志

### 13.2 进入 initramfs shell

如果 switch_root 失败,initramfs 会自动启动一个 shell。
修改 `init` 脚本,把它改成:
```sh
exec /bin/sh
```
然后重启。

### 13.3 关闭显示管理(快速诊断)

如果 GNOME 启动后屏幕黑屏,临时改用 TTY:
1. 编辑 `/etc/gdm3/custom.conf`,在 [daemon] 段设 `WaylandEnable=false`
2. 重启
3. 如果 TTY 也不显示,说明 kernel 显示驱动有问题
