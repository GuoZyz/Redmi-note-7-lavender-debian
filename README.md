# 红米 Note 7 (lavender / sdm660) Debian 13 + GNOME 移植项目

> ⚠️ **重要警告**: 这是一个高风险实验项目。在真机刷入 boot.img 之前,请:
> 1. 备份原 boot.img:`adb shell dd if=/dev/block/bootdevice/by-name/boot of=/sdcard/boot_stock.img`
> 2. 备份 userdata / internal storage
> 3. 确保已解锁 bootloader (OEM unlocking + fastboot unlock)
> 4. 准备 TWRP 救砖
>
> **刷机失败变砖不归本项目负责**

> 🤖 **AI 协作声明**: 本项目大量由 AI (ZCode, MiniMax M3) 协助完成,包括:
> - 诊断 19 次 GitHub Actions 构建失败的根因
> - 修补 LineageOS sdm660 内核源码中 8 个 Makefile 缺失的 `-I` 头文件路径
> - 编写本地构建脚本 (debootstrap + chroot 安装 + 打包)
> - 编写 initramfs 的 `init` 脚本 (switch_root 逻辑)
> - 调试 Debian trixie 包依赖 (pipewire vs pulseaudio 冲突、合并 usr 布局)
>
> 人类 (GuoZy) 提供环境、硬件指令和最终验证决策。

---

## 📊 项目状态

| 阶段 | 状态 | 证据 |
|---|---|---|
| 内核源码下载 | ✅ 完成 | LineageOS `android_kernel_xiaomi_sdm660` `lineage-18.1` |
| 内核配置 | ✅ 完成 | `lavender_defconfig` + Debian 必需选项 |
| **内核编译** | ✅ **成功** | `arch/arm64/boot/Image.gz-dtb` = **15.28 MB** |
| **boot.img 打包** | ✅ **成功** | AOSP magic OK, 15.79 MB |
| **rootfs debootstrap** | ✅ **成功** | minbase, 239 MB, 1m33s |
| **chroot 安装 GNOME** | ✅ **成功** | 1166 个 deb 包, 3.8 GB, ~5 min |
| **rootfs.tar.gz 打包** | ✅ **成功** | 1.1 GB, 99,711 文件 |
| 真机刷机验证 | ⏳ 未做 | 显示/触屏/Modem/WiFi/音频 待适配 |

---

## 🗂️ 仓库结构

```
.
├── README.md              # 本文件
├── CONFIGURATION.md       # 内核 CONFIG 选项说明
├── initramfs/             # 启动用的 initramfs 内容
│   ├── bin/               # 符号链接占位 (由构建脚本填充)
│   ├── etc/               # 同上
│   └── init               # switch_root 入口脚本
├── scripts/               # 本地构建脚本 (aarch64 Debian 13)
│   ├── 01-debootstrap.sh           # 阶段 1: 创建基础 rootfs
│   ├── 02-configure-rootfs.sh      # 阶段 2: 安装 GNOME + 配置
│   ├── 03-install-kernel-modules.sh# 阶段 3: 安装内核模块 + dtb
│   └── 04-tar-rootfs.sh            # 阶段 4: 打包 rootfs.tar.gz
├── tools/                 # 辅助工具
│   ├── extract_firmware.sh         # 提取固件 (from stock boot.img)
│   └── unpack_bootimg.py           # 解包 boot.img
└── .gitignore
```

**不再包含**:
- ❌ `.github/workflows/` — 旧的 GitHub Actions 已废弃
- ❌ `build.yml` — 同上
- ❌ `push-to-github.sh` — 推送助手脚本

---

## 🚀 本地编译 (推荐)

> 适合在 **aarch64 Debian 13** 主机上直接构建。已在主机 `aarch64 / Debian 13.6 / 8 核 / 7.3G RAM / 70G 磁盘` 上**全流程验证**。

### 0. 前置依赖

```bash
sudo apt-get update
sudo apt-get install -y \
    debootstrap qemu-user-static \
    gcc-aarch64-linux-gnu g++-aarch64-linux-gnu \
    binutils-aarch64-linux-gnu libssl-dev \
    ccache mkbootimg dosfstools e2fsprogs
```

### 1. 克隆内核源码并打补丁

```bash
mkdir -p ~/kernel-build
cd ~/kernel-build
git clone --depth=1 -b lineage-18.1 \
    https://github.com/LineageOS/android_kernel_xiaomi_sdm660.git

cd android_kernel_xiaomi_sdm660

# === 修补 8 个缺失 -I 的 Makefile (必要!) ===
# 见 CONFIGURATION.md 的修补逻辑

# 加载默认配置
make lavender_defconfig

# 编译内核 + dtbs
time make -j$(nproc) \
    ARCH=arm64 \
    CROSS_COMPILE=aarch64-linux-gnu- \
    KCFLAGS="-Wno-error" \
    Image.gz-dtb
```

**预期**: 5-10 分钟后 `arch/arm64/boot/Image.gz-dtb` 生成,大小约 15 MB。

### 2. 构建 rootfs (用本仓库的脚本)

```bash
cd /path/to/this/repo
sudo bash scripts/01-debootstrap.sh
sudo bash scripts/02-configure-rootfs.sh
sudo bash scripts/03-install-kernel-modules.sh  # Android defconfig 下是空操作
sudo bash scripts/04-tar-rootfs.sh
```

**预期**:
- 第 1 步: ~2 分钟 (debootstrap)
- 第 2 步: ~5-10 分钟 (apt 装 1166 个 deb 包)
- 第 3 步: ~1 秒 (Android 内核所有驱动都 =y)
- 第 4 步: ~2 分钟 (打包 1.1GB tar.gz)

**最终产物**:
```
/home/<user>/note7-debian-local-build/
├── rootfs/                     # 展开的 rootfs (3.8 GB)
│   └── boot/Image.gz-dtb       # 内核 (15.28 MB)
└── rootfs.tar.gz               # 打包的 rootfs (1.1 GB)
```

### 3. 打包 boot.img

需要从 stock 设备 dump 出来的 `boot.img` 提取 ramdisk + 命令行参数,然后用 mkbootimg 重新打包。

参见 `CONFIGURATION.md` 和 `tools/extract_firmware.sh`。

---

## 🔧 内核修补说明 (重要)

LineageOS sdm660 源码 (lineage-18.1) 的 **8 个 Makefile 缺少 `-I` 头文件路径**,导致在 GCC 高版本下编译失败。本项目已通过 `sed` 注入 `ccflags-y += -I$(srctree)/...` 解决。

### 受影响的 Makefile

| 路径 | 缺失的头文件目录 |
|---|---|
| `drivers/gpu/msm/Makefile` | `kgsl_trace.h` 循环包含 |
| `drivers/input/misc/vl53L0/Makefile` | `stmvl53l0-i2c.h` |
| `drivers/bluetooth/Makefile` | `btfm_slim.h` |
| `drivers/net/ethernet/msm/Makefile` | `rndis_ipa_trace.h` |
| `drivers/media/platform/msm/camera_v2/common/Makefile` | `msm_camera_i2c.h` 等 |
| `drivers/media/platform/msm/camera_v2/isp/Makefile` | `msm_isp.h` 等 |
| `drivers/media/platform/msm/camera_v2/sensor/io/Makefile` | `msm_sensor_driver.h` |
| `drivers/platform/msm/ipa/ipa_v2/Makefile` | `ipa_trace.h` |
| `drivers/platform/msm/ipa/ipa_v3/Makefile` | `ipa_trace.h` |
| `drivers/soc/qcom/Makefile` | `tracer_pkt_private.h` |

### 禁用的 CONFIG (仅 ARM64-only)

| 选项 | 原因 |
|---|---|
| `CONFIG_COMPAT_VDSO` | 避免依赖 ARM32 工具链 |
| `CONFIG_CROSS_COMPILE_ARM32` | 同上 |
| `CONFIG_VDSO32` | 同上 |

---

## 🎯 真机刷机流程

> ⚠️ **以下步骤需要在真机上完成,本项目尚未验证**

### 准备工作

1. 解锁 bootloader:`Settings → About phone → tap Build number 7 times → Developer options → OEM unlocking → enable`
2. 重启到 fastboot:`adb reboot bootloader`
3. 验证:`fastboot devices`

### 准备 rootfs 分区

```bash
# 把 rootfs 刷到一个 ext4 分区 (用户数据分区或自定义分区)
# ⚠️ 注意: 这会清空该分区所有数据
mkfs.ext4 /dev/mmcblk0p77        # 或你选定的分区
mkdir /mnt/rootfs
mount /dev/mmcblk0p77 /mnt/rootfs

# 解压 rootfs
tar -xzf rootfs.tar.gz -C /mnt/rootfs

# 修改 fstab (必须!)
sed -i 's/mmcblk0pXX/mmcblk0p77/' /mnt/rootfs/etc/fstab
umount /mnt/rootfs
```

### 准备 boot.img

```bash
# 从 stock boot.img 提取命令行
python tools/unpack_bootimg.py --boot_img boot_stock.img --out stock_unpacked

# 重新打包 (用新内核 + initramfs)
mkbootimg \
    --kernel out/Image.gz-dtb \
    --ramdisk initramfs.cpio.gz \
    --cmdline "$(cat stock_unpacked/cmdline)" \
    --base 0x80000000 \
    --kernel_offset 0x8000 \
    --ramdisk_offset 0x1000000 \
    --tags_offset 0x100 \
    --pagesize 4096 \
    --dt out/dt.img \
    --output out/boot.img
```

### 刷机

```bash
fastboot flash boot out/boot.img
fastboot reboot
```

---

## 🐛 已知问题

### 真机未验证

- ❓ 显示输出 (framebuffer / DRM / QCOM display)
- ❓ 触屏 (input subsystem, synaptics)
- ❓ Modem (QMI / QCMAP)
- ❓ WiFi (wlan.ko / cnss)
- ❓ 音频 (alsa/pulseaudio/pipewire + Q6 DSP)
- ❓ 传感器 (sensors.c)

### 软件包冲突

- `pipewire-audio` 与 `pulseaudio` 互斥 — Debian trixie 默认装 pipewire (PipeWire + pulseaudio 兼容层),功能等价。

### initramfs 默认行为

- 默认扫描 `mmcblk0p49-80` + `mmcblk1p1-2` 寻找 ext4 分区
- **用户必须根据自己的分区表修改 `initramfs/init` 第 28-29 行**

---

## 📜 旧项目历史 (已废弃)

本项目曾尝试用 **GitHub Actions** 自动构建,但因 GitHub CI 网络限制 (`github.com` 访问受限) **连续失败 19 次**(详见旧 commit `7502826`)。

现已改为**本地构建**,所有脚本在 `scripts/` 下,且已在本地验证**全流程跑通**(内核 + rootfs + 打包)。

旧 workflow 文件 `build.yml` (含 8 个 Makefile 修补逻辑) **已从仓库移除**。

---

## 🤝 致谢

- **LineageOS** 项目 (`android_kernel_xiaomi_sdm660`)
- **Debian** 项目 (trixie 13)
- **GNOME** 桌面环境
- **ZCode / MiniMax M3** AI 协作
- 清华 TUNA 镜像 (`mirrors.tuna.tsinghua.edu.cn`)
- mkbootimg (AOSP 工具)
- 所有把 Android 内核移植到 Linux 桌面系统的先驱者 (Nokia N900, PinePhone)

---

## 📄 许可证

本项目代码采用 **MIT License**。内核、Debian、GNOME 等组件遵循各自许可证。