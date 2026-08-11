#!/bin/bash
# 本地编译 rootfs - 第 2 步: chroot 安装 GNOME + 网络 + 音频 + 用户配置
# 等价于 build.yml 的 "配置 rootfs 基础" + "配置 rootfs 用户和系统设置"
#
# 前置: 必须先运行 01-debootstrap.sh
# 用法: sudo bash 02-configure-rootfs.sh

set -euo pipefail

ROOTFS="/home/GuoZy/note7-debian-local-build/rootfs"
LOG="/home/GuoZy/note7-debian-local-build/logs/02-configure-rootfs.log"

if [ ! -x "$ROOTFS/bin/sh" ]; then
    echo "✗ rootfs 未初始化,请先运行 01-debootstrap.sh"
    exit 1
fi

# 必须是 root (chroot + mount 需要)
if [ "$(id -u)" -ne 0 ]; then
    echo "✗ 必须以 root 运行"
    exit 1
fi

echo "==== 步骤 2/4: chroot 安装 GNOME + 网络 + 配置 ===="
echo "  ROOTFS = $ROOTFS"
echo "  LOG    = $LOG"
echo

# 复制 qemu 模拟器 (虽然我们是 native aarch64,但保留也无害)
cp /usr/bin/qemu-aarch64-static "$ROOTFS/usr/bin/" 2>/dev/null || true

# 挂载虚拟文件系统 (用 mount --bind 不用 sudo)
echo "==== 挂载 /dev /proc /sys 到 rootfs ===="
mount --bind /dev  "$ROOTFS/dev"  || { echo "✗ mount /dev 失败"; exit 1; }
mount --bind /proc "$ROOTFS/proc" || { echo "✗ mount /proc 失败"; exit 1; }
mount --bind /sys  "$ROOTFS/sys"  || { echo "✗ mount /sys 失败"; exit 1; }

# 卸载 hook
cleanup_mounts() {
    echo
    echo "==== 清理挂载点 ===="
    umount "$ROOTFS/sys"  2>/dev/null || true
    umount "$ROOTFS/proc" 2>/dev/null || true
    umount "$ROOTFS/dev"  2>/dev/null || true
}
trap cleanup_mounts EXIT

# chroot 安装 (估计 30-60 分钟,主要时间在 apt 下载)
echo "==== chroot 执行安装 (这一步耗时最长) ===="
chroot "$ROOTFS" /bin/bash -c '
set -e
export DEBIAN_FRONTEND=noninteractive
export LC_ALL=C
export LANG=C

echo "==== [1/7] 配置清华源 ===="
cat > /etc/apt/sources.list << SOURCES
deb https://mirrors.tuna.tsinghua.edu.cn/debian trixie main contrib non-free non-free-firmware
deb https://mirrors.tuna.tsinghua.edu.cn/debian trixie-updates main contrib non-free non-free-firmware
deb https://mirrors.tuna.tsinghua.edu.cn/debian trixie-backports main contrib non-free non-free-firmware
deb https://mirrors.tuna.tsinghua.edu.cn/debian-security trixie-security main contrib non-free non-free-firmware
SOURCES

echo "==== [2/7] apt-get update ===="
apt-get update 2>&1 | tail -10

echo "==== [3/7] 安装基础包 ===="
apt-get install -y --no-install-recommends \
    locales sudo openssh-server ca-certificates \
    initramfs-tools busybox kmod udev dbus \
    console-setup keyboard-configuration 2>&1 | tail -10

echo "==== [4/7] 安装 GNOME ===="
apt-get install -y --no-install-recommends \
    gnome gnome-shell gdm3 gnome-terminal nautilus \
    gnome-control-center gnome-tweaks \
    xdg-utils xdg-user-dirs 2>&1 | tail -10

echo "==== [5/7] 安装网络/Modem/蓝牙/音频 ===="
apt-get install -y --no-install-recommends \
    network-manager modemmanager ppp wpasupplicant wireless-tools \
    rfkill bluez bluez-tools \
    alsa-utils pulseaudio pipewire pipewire-audio pipewire-pulse \
    fonts-noto-cjk fonts-noto-color-emoji 2>&1 | tail -10

echo "==== [6/7] 安装工具 ===="
apt-get install -y --no-install-recommends \
    bash-completion less vim-tiny nano htop curl wget git \
    tzdata chrony ntpsec-ntpdate 2>&1 | tail -10

echo "==== [6.5/7] 安装 power (可选) ===="
apt-get install -y --no-install-recommends \
    upower power-profiles-daemon 2>&1 | tail -5 || echo "  (upower 跳过)"

echo "==== [7/7] 用户/系统配置 ===="
# root 密码
echo "root:126112" | chpasswd
# 主用户 note7
useradd -m -s /bin/bash -G sudo,audio,video,plugdev,netdev,bluetooth note7
echo "note7:126112" | chpasswd

# 主机名
echo "lavender-debian" > /etc/hostname
cat > /etc/hosts << HOSTS
127.0.0.1   localhost
127.0.1.1   lavender-debian
::1         localhost ip6-localhost ip6-loopback
fe00::0     ip6-localnet
ff00::0     ip6-mcastprefix
ff02::1     ip6-allnodes
ff02::2     ip6-allrouters
HOSTS

# 时区
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
dpkg-reconfigure -f noninteractive tzdata

# Locale
sed -i "s/# en_US.UTF-8/en_US.UTF-8/" /etc/locale.gen
sed -i "s/# zh_CN.UTF-8/zh_CN.UTF-8/" /etc/locale.gen
locale-gen
update-locale LANG=en_US.UTF-8

# fstab (用户必须按真机修改)
cat > /etc/fstab << FSTAB
# <file system>  <mount point>  <type>  <options>         <dump>  <pass>
/dev/mmcblk0pXX  /              ext4    defaults,noatime  0       1
tmpfs           /tmp           tmpfs   defaults,noatime,mode=1777  0  0
tmpfs           /var/tmp       tmpfs   defaults,noatime,mode=1777  0  0
tmpfs           /run           tmpfs   defaults,noatime,mode=755   0  0
FSTAB

# 启用 systemd 服务
systemctl enable gdm3 NetworkManager ModemManager sshd 2>&1 | tail -5
systemctl enable bluetooth upower 2>&1 | tail -3 || true

# GNOME 首次配置跳过
mkdir -p /etc/skel
touch /etc/skel/.config/gnome-initial-setup-done

# sudo
echo "note7 ALL=(ALL) ALL" > /etc/sudoers.d/note7
chmod 440 /etc/sudoers.d/note7

# NetworkManager 管理所有设备
mkdir -p /etc/NetworkManager/conf.d
cat > /etc/NetworkManager/conf.d/10-globally-managed-devices.conf << NMCONF
[keyfile]
unmanaged-devices=none
NMCONF

# 串口 getty (调试)
systemctl enable serial-getty@ttyHSL0.service 2>&1 | tail -3 || true

echo "==== [7/7] 清理 apt 缓存 ===="
apt-get clean
rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

echo "==== chroot 全部完成 ===="
echo "  用户: note7 / 126112 (sudo)"
echo "  用户: root  / 126112"
' 2>&1 | tee "$LOG"

echo
echo "==== 第 2 步完成 ===="
du -sh "$ROOTFS/"
echo
echo "✓ 第 2 步完成,运行第 3 步: bash 03-install-kernel-modules.sh"
