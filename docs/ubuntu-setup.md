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

**现象**：某天起 Claude Code 底部的 statusline（context、5h/7d 用量、花费）不见了，主题回到默认，插件全部失效。`~/.claude/statusline/statusline.sh` 明明还在，手动喂 JSON 也跑得出来。`~/.claude/settings.json` 从几千字节缩到一百出头，只剩 `env` 和 `model`。

**根因**：`cc-switch` 每次切换供应商（以及启动时）都会重写 `~/.claude/settings.json`。它有个原生机制叫**公共配置（Common Config）**，存在 `~/.cc-switch/cc-switch.db` 的 `settings` 表 `common_config_claude` 键里，切换时合并进 `settings.json`——但它是**按供应商逐个开关的**（provider 行 `meta.commonConfigEnabled`）。

真正的坑在于：几个第三方供应商当初都勾了，唯独**切回来的那个 Claude Official 没勾**。所以切去 DeepSeek 时一切正常，切回官方时公共配置不写入，`statusLine` / `theme` / `enabledPlugins` 一起消失。

**修复**：GUI → 编辑供应商 → Claude Official → 勾上「写入公共配置」，然后切换一次。四个供应商都勾上后，切换会自动带回全套键，不需要跑任何命令。

勾上之后是**深度合并**：公共配置里没有的键（如 `modelSettings`）和已有对象的子键（如 `statusLine.padding`）都会保留。cc-switch 还会把 live 配置回填进公共配置。

**不要**把 `~/.claude/settings.json` 纳入 chezmoi。切到第三方供应商时 cc-switch 会往它的 `env` 写明文 `ANTHROPIC_AUTH_TOKEN`，而 `TIMHX/dotfiles` 是**公开仓库**，一次 `chezmoi add` 就泄漏了。所以 `.chezmoiignore` 对 `~/.claude` 采用先全忽略、再逐条 `!` 放行的白名单，只放 `CLAUDE.md`、`skills/`、`statusline/`——不含 `settings.json`。

跨机器复用靠 `docs/cc-switch-common-config.json`（公共配置的脱敏导出，剔除了 `autoMode` 那段本机安全扫描），在新机器上手工填进 cc-switch 的「编辑公共配置」即可。公共配置里的路径记得用 `~` 而非绝对路径。

---

## 与 VPS 的差异

- VPS 用 apt 装系统包，桌面用 brew（免 sudo）
- VPS 有 doppler/hermes 配置，桌面版已精简
- dotfiles 共用 `TIMHX/dotfiles.git`，双向同步
