# GitHub Personal Access Token (PAT) 生成指南

## 步骤 1: 打开 GitHub Token 设置页面

直接在浏览器地址栏输入,或者点击这里:

**https://github.com/settings/tokens**

或者手动:
1. 登录 GitHub
2. 点击右上角头像 → **Settings**
3. 左侧菜单最下角 → **Developer settings**
4. 左侧 → **Personal access tokens** → **Tokens (classic)**
5. 右上角 → **Generate new token** → **Generate new token (classic)**
   - 注意: GitHub 现在默认推荐 Fine-grained tokens,但 classic token 兼容性最好

## 步骤 2: 配置 Token

**Note (备注)**:
```
note7-debian-push
```
随便写,自己认识就行

**Expiration (过期时间)**:
- 建议选 `30 days` 或 `No expiration` (看你需要)
- 如果担心安全,选 7 天

**Select scopes (权限范围)** - 只需要勾选:
- ✅ **repo** (完整仓库访问 - 推送需要)
- ❌ 其他都不要勾(最小权限原则)

## 步骤 3: 点击 "Generate token"

页面会显示一段乱码一样的字符串,例如:
```
ghp_aBcDeFgHiJkLmNoPqRsTuVwXyZ0123456789
```

**⚠️ 这是唯一一次看到的机会,关闭页面后无法再看到完整 token!**

## 步骤 4: 复制 token

点击 token 旁边的 📋 图标复制。

## 步骤 5: 粘贴给我

回到这个对话,把 token 粘贴到输入框。

我会:
1. 用 token 推送代码(只用一次)
2. 立即从内存中清除(token 不写入任何文件、不入 git 历史)
3. 推送完成后告诉你结果

---

## 推送命令预览(我即将执行的)

```bash
cd ~/note7-debian/actions/note7-debian-gh
# 用 token 推送(用户名:GuoZyz)
git push -u https://GuoZyz:<你的token>@github.com/GuoZyz/Redmi-note-7-lavender-debian.git main
# 推送后 token 立刻失效
```

## 安全说明

- token 只在内存中使用,推送后立即销毁
- 不会写入任何文件(包括 `~/.git/credentials`)
- 不会出现在 git 历史中
- 不会出现在记录.txt 中(完整 token 不记录)
- 你生成 token 时设置的过期时间到期后,token 自动失效
- 你可以随时在 https://github.com/settings/tokens 撤销

## 常见问题

**Q: token 是什么格式?**
A: 以 `ghp_` 或 `github_pat_` 开头的长字符串

**Q: 我忘了 token,能再生成一个吗?**
A: 可以,旧的撤销,生成新的

**Q: token 会过期吗?**
A: 会,在你设置的过期时间后自动失效

**Q: 推送后我能不能撤销这个 token?**
A: 能,去 https://github.com/settings/tokens 找到 `note7-debian-push` 点 Delete
