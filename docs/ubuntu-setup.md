# Ubuntu Desktop 开发环境安装指南

> tim-pc (9100 PRO SSD) · Ubuntu 26.04 LTS · 2026-07-14

## 前置条件

- Ubuntu 26.04 LTS 已安装，用户 `xing` 有 sudo 权限
- Tailscale 已配置
- Homebrew (Linuxbrew) 已安装

---

## 安装清单

### L1 — Shell 基础

| 工具 | 用途 | 方式 | 版本 |
|------|------|------|------|
| zsh | 现代 shell，替代 bash | brew | 5.9.2 |
| oh-my-zsh | zsh 框架（主题/插件） | curl 脚本 | latest |
| starship | 跨 shell 提示符 | curl → ~/.local/bin | latest |
| fzf | 模糊搜索（Ctrl+R/T） | brew | 0.74.0 |
| zoxide | 智能 cd（`z <name>`） | curl → ~/.local/bin | latest |

### L2 — 现代化 CLI 替代品

| 工具 | 替代 | 安装 |
|------|------|------|
| ripgrep (rg) | grep | brew |
| fd-find (fd) | find | brew |
| bat | cat（语法高亮） | brew |
| eza | ls（图标 + git） | brew |
| git-delta | git diff | brew |

### L3 — 开发运行时

| 工具 | 用途 | 方式 | 版本 |
|------|------|------|------|
| nvm | Node.js 版本管理 | curl 脚本 | 0.40.1 |
| uv | Python 包管理 | curl → ~/.local/bin | 0.11.28 |
| neovim | 现代 Vim | brew | 0.12.4 |

### L4 — Dotfiles

| 工具 | 用途 | 仓库 |
|------|------|------|
| chezmoi | dotfiles 版本控制 | `TIMHX/dotfiles.git` |

### L5 — 会话

| 工具 | 用途 |
|------|------|
| sesh | tmux session 管理 + fzf 切换 |

---

## 安装步骤

### Step 1: brew 批量安装

```bash
brew install fzf ripgrep fd bat eza git-delta zsh neovim
```

### Step 2: oh-my-zsh

```bash
export PATH="/home/linuxbrew/.linuxbrew/bin:$PATH"
RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
```

### Step 3: CLI 工具到 ~/.local/bin

```bash
mkdir -p ~/.local/bin

curl -sS https://starship.rs/install.sh | sh -s -- -y --bin-dir ~/.local/bin
curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
curl -LsSf https://astral.sh/uv/install.sh | sh
curl -fsSL get.chezmoi.io | sh -s -- -b ~/.local/bin
curl -sSL https://github.com/joshmedeski/sesh/releases/download/v2.27.0/sesh_Linux_x86_64.tar.gz | tar xz -C ~/.local/bin/ sesh
```

### Step 4: chezmoi 初始化

```bash
export PATH="$HOME/.local/bin:$PATH"
chezmoi init --apply TIMHX/dotfiles.git
```

### Step 5: sudo 步骤

```bash
echo "/home/linuxbrew/.linuxbrew/bin/zsh" | sudo tee -a /etc/shells
sudo chsh -s /home/linuxbrew/.linuxbrew/bin/zsh xing
echo "xing ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/xing
sudo chmod 0440 /etc/sudoers.d/xing
```

### Step 6: GitHub SSH key

```bash
ssh-keygen -t ed25519 -C "xing@tim-pc-ubuntu" -f ~/.ssh/id_ed25519 -N ""
# 将 ~/.ssh/id_ed25519.pub 添加到 GitHub → Settings → SSH Keys
```

---

## 验证

```bash
# PATH
echo $PATH | tr ':' '\n' | grep -E 'local/bin|linuxbrew'

# 所有工具应返回路径
which zsh starship fzf zoxide rg fd bat eza delta nvim chezmoi sesh uv

# chezmoi 无 diff
chezmoi status
```

---

## 目录结构

```
~/
├── .local/bin/              # starship, zoxide, uv, chezmoi, sesh
├── .config/
│   └── starship.toml        # chezmoi 管理（gruvbox_dark 主题）
├── .oh-my-zsh/              # oh-my-zsh
├── .nvm/                    # Node.js
├── .local/share/chezmoi/    # dotfiles git repo
├── .claude/                 # Claude Code（白名单纳管，见踩坑记录）
├── .zshrc                   # chezmoi 管理
└── .ssh/id_ed25519          # GitHub
```

## 踩坑记录

### `starship.toml` 未加入 chezmoi → 终端看不见主题

**现象**：`chezmoi apply` 后 `eval "$(starship init zsh)"` 正常执行，但 starship 跑默认极简预设（`user in host in path \n ❯`），看起来跟没装一样。

**根因**：`.zshrc` 加入了 chezmoi，但 `~/.config/starship.toml` 忘了 `chezmoi add`。

**修复**：`chezmoi add ~/.config/starship.toml` → commit → push。新机器 `chezmoi apply` 即可。

### starship 图标显示希腊字母 (Ω, Φ) 乱码

**现象**：终端里 starship 图标变成 Ω、Φ 等希腊字母。

**根因**：GNOME Terminal 有两个开关—— `font` 设了 Nerd Font 不够，`use-system-font` 默认为 `true` 会覆盖自定义字体。

**修复**：
```bash
PROFILE=$(gsettings get org.gnome.Terminal.ProfilesList default | tr -d "'")
gsettings set "org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$PROFILE/" font 'MesloLGS Nerd Font Mono 12'
gsettings set "org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$PROFILE/" use-system-font false
```
验证: `starship prompt` 应输出图标而非希腊字母。新开终端窗口生效。

### cc-switch 切换供应商 → Claude Code statusline / 主题 / 插件消失

**现象**：某天起 Claude Code 底部的 statusline（context、5h/7d 用量、花费）不见了，主题也回到默认，插件全部失效。`~/.claude/statusline/statusline.sh` 明明还在，手动喂 JSON 也跑得出来。

**根因**：Claude 用量跑满时用 `cc-switch` 切到别的大模型，它会**整文件重写** `~/.claude/settings.json` 来注入 `ANTHROPIC_BASE_URL` / `ANTHROPIC_AUTH_TOKEN` / `ANTHROPIC_*_MODEL`，而不是合并。它不认识的键（`statusLine`、`theme`、`enabledPlugins`）会被直接丢掉，文件从几百字节缩到一百出头。

**修复**：把 `settings.json` 纳入 chezmoi，切换后 `chezmoi apply ~/.claude/settings.json` 恢复；或手动补回：

```bash
cd ~/.claude
cp settings.json settings.json.bak-$(date +%Y%m%d-%H%M%S)
jq '. + {statusLine: {type: "command", command: "~/.claude/statusline/statusline.sh", padding: 0}}' \
  settings.json > settings.json.tmp && mv settings.json.tmp settings.json
```

需重启 Claude Code 生效（`statusLine` 是启动时读的）。

**注意**：cc-switch 会把第三方 API key 明文留在 `~/.claude/settings.json` 和 `~/.claude/backups/*.bak` 里。`TIMHX/dotfiles` 是**公开仓库**，所以 `.chezmoiignore` 对 `~/.claude` 采用先全忽略、再逐条 `!` 放行的白名单策略，只放 `CLAUDE.md`、`settings.json`、`skills/`、`statusline/`。

---

## 与 VPS 的差异

- VPS 用 apt 装系统包，桌面用 brew（免 sudo）
- VPS 有 doppler/hermes 配置，桌面版已精简
- dotfiles 共用 `TIMHX/dotfiles.git`，双向同步
