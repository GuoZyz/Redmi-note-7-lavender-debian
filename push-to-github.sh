#!/bin/bash
# 推送项目到 GitHub 的辅助脚本
# 用法: GITHUB_TOKEN=xxx ./push-to-github.sh 用户名/仓库名
# 或者直接 git push

set -e

PROJ_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJ_DIR"

# 检查 git
if ! command -v git >/dev/null 2>&1; then
    echo "错误: 需要 git"
    exit 1
fi

# 默认仓库名
REPO_NAME="${1:-note7-debian}"

# 如果没初始化,初始化
if [ ! -d .git ]; then
    echo "==== 初始化 git 仓库 ===="
    git init
    git config user.email "note7-debian-builder@local"
    git config user.name "Note7 Debian Builder"
    git branch -M main
fi

# 添加所有文件
echo "==== 添加文件 ===="
git add .gitignore README.md scripts/ initramfs/ .github/

echo "==== 待提交文件 ===="
git status --short | head -30

echo ""
echo "==== 提交 ===="
git commit -m "Initial: GitHub Actions pipeline for Note7 (lavender) Debian 13 + GNOME

- Compile kernel from LineageOS/android_kernel_xiaomi_sdm660 lineage-18.1
- Build Debian 13 (trixie) ARM64 rootfs via debootstrap
- Install full GNOME desktop + gdm3 + NetworkManager + ModemManager + bluez
- Create minimal initramfs (busybox + init script) for switch_root
- Package boot.img using mkbootimg with lavender boot parameters
- Upload boot.img + rootfs.tar.gz + Image.gz-dtb as artifacts
- Default passwords: root/126112, note7/126112" || echo "(已是最新)"

echo ""
echo "==== 推送 ===="
echo "请选择推送方式:"
echo "1) HTTPS + 用户名密码"
echo "2) SSH (需已配置 ssh key)"
echo "3) 仅初始化,手动推送"
echo ""
read -p "请输入选项 [1/2/3]: " CHOICE

case "$CHOICE" in
    1)
        git remote add origin "https://github.com/$REPO_NAME.git" 2>/dev/null || \
            git remote set-url origin "https://github.com/$REPO_NAME.git"
        git push -u origin main
        ;;
    2)
        git remote add origin "git@github.com:$REPO_NAME.git" 2>/dev/null || \
            git remote set-url origin "git@github.com:$REPO_NAME.git"
        git push -u origin main
        ;;
    3)
        echo "未推送。手动推送命令:"
        echo "  cd $PROJ_DIR"
        echo "  git remote add origin https://github.com/$REPO_NAME.git"
        echo "  git push -u origin main"
        ;;
    *)
        echo "无效选项"
        exit 1
        ;;
esac

echo ""
echo "==== 完成 ===="
echo "下一步: 访问 https://github.com/$REPO_NAME/actions 触发构建"
