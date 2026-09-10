# dotfiles

chezmoi 管理的个人配置。源目录 `~/.local/share/chezmoi`，应用到 `~`。

```bash
chezmoi diff          # 看看会改什么
chezmoi apply         # 应用到 home
chezmoi re-add <file> # 把本机改动收回源目录
```

`.claude/` 默认整棵忽略、按 allowlist opt-in；`settings.json` 不纳管（cc-switch 会往里写明文
API key，本仓库是公开的）。详见 `.chezmoiignore`。

---

## 机器

三台共用这一个仓库。用户名和家目录统一为 `xing` / `/home/xing`。

| | tim-pc | vps (racknerd) | aliyun |
|---|---|---|---|
| 角色 | Ubuntu 桌面（双系统） | 主服务器，安全基线 | 境内 exit node |
| 包管理 | Homebrew | apt | apt + 镜像 |
| zsh | brew | `/usr/bin/zsh` | `/usr/bin/zsh` |
| starship | `~/.local/bin` | `/usr/local/bin` | `~/.local/bin` |
| zoxide / fzf / sesh | ✅ | ✅ | ✅ |
| eza / bat / fd | ✅ | ✗ | ✗ |
| rg | ✅ | ✅ | ✗ |
| 专属 | — | doppler / hermes | — |

---

## zsh

配置：`dot_zshrc.tmpl` → `~/.zshrc`

**改模板，不要改 `~/.zshrc`** —— 下次 `chezmoi apply` 会覆盖。

设计原则是**机器差异优先靠特性探测，而不是主机名分支**。brew、nvm、starship、zoxide、
sesh、eza/bat/fd/rg 全部 `command -v` 判断，装了才启用；`ls` / `grep` 有现代版就用现代版，
没有就回退原生。所以同一份配置三端都能直接跑，加新机器通常**不需要改模板**。

全文件只有一处 `{{ if eq .chezmoi.hostname }}` 分支，包住 VPS 的 doppler 和 hermes ——
它们本就只该存在于那一台。

自带的几个函数：`czp` 收改动并提交推送、`cza <file>` 加文件再走 `czp`、`czu` 拉取更新、
`t` 用 sesh + fzf 切 tmux session。

---

## tmux

前缀键改成了 **`Ctrl+a`**（默认的 `Ctrl+b` 已解绑）。下面所有快捷键都是「先按 `Ctrl+a`，松开，再按后一个键」。

配置：`dot_tmux.conf.tmpl` → `~/.tmux.conf`
配套脚本：`bin/executable_cc-layout` → `~/bin/cc-layout`

### 面板布局（自定义）

一键把当前 window 铺成 N 格。面板**变多直接加**，**变少会先弹 y/n 确认**；目标数等于当前数时只重排布局。新面板继承当前面板的目录，不自动启动任何程序。

| 键 | 布局 |
|---|---|
| `Ctrl+a 1` | 1 格，独占整个 window |
| `Ctrl+a 2` | 2 格，左右平分 |
| `Ctrl+a 3` | 3 格，左边一个大格（55% 宽、全高）+ 右边上下两格 |
| `Ctrl+a 4` | 4 格，四宫格 |

> 代价：`Ctrl+a 1/2/3/4` 不再是「跳到 N 号 window」。切 window 见下面一节。

实现在 `~/bin/cc-layout N <pane_id>`，绑定里用 `if-shell -F '#{>:#{window_panes},N}'` 判断是否
需要确认，所以确认逻辑在 tmux 层、脚本本身无条件执行。脚本**必须**拿到 pane id（绑定传
`#{pane_id}`，交互式 shell 用 `TMUX_PANE`），不会 fallback 到无 target 的 `display`——那会解析成
当前 attach 的 client 的活动面板，多 client 时会打错 window。

### 面板导航

| 键 | 作用 |
|---|---|
| `Ctrl+a o` / `Ctrl+a Tab` | 依次轮换到下一个面板，到底绕回。可连点（`-r`，`repeat-time` 500ms 内不用重按前缀） |
| `Ctrl+a ←→↑↓` | 按方向切换面板，同样可连点 |
| `Ctrl+a ;` | 在最近两个面板之间来回跳 |
| `Ctrl+a q` 再按数字 | 屏上显示每格编号，直接跳过去 |
| `Ctrl+a z` | 当前面板全屏 / 还原 |

### 面板增删

| 键 | 作用 |
|---|---|
| `Ctrl+a \|` | 垂直分屏（左右），保留当前目录 |
| `Ctrl+a -` | 水平分屏（上下），保留当前目录 |
| `Ctrl+a x` | 关掉当前面板 |
| 鼠标右键 | 弹出菜单：全屏、分屏、关闭面板（危险操作二次确认） |

默认的 `Ctrl+a "` 和 `Ctrl+a %` 已解绑。

### Window 与 Session

| 键 | 作用 |
|---|---|
| `Ctrl+a w` | 列出所有 window 选一个 |
| `Ctrl+a n` / `Ctrl+a p` | 下一个 / 上一个 window |
| `Ctrl+a 0` | 跳到 0 号 window（`1-4` 已被布局占用） |
| `Ctrl+a c` | 新建 window |
| `Ctrl+a s` | 列出所有 session 选一个 |
| `Ctrl+a f` | sesh + fzf 模糊跳转，跨 session / 配置目录 / zoxide 历史 |
| `Ctrl+a :` | 输入 tmux 命令，如 `new`、`kill-session` |
| `Ctrl+a Ctrl+a` | 发送一个真正的 `Ctrl+a` 给终端程序（比如跳到行首） |

`Ctrl+a f` 依赖 `sesh`、`fzf`、`fd`、`zoxide`，都装在 `~/.local/bin` 或 Homebrew 下。

### 把两个 session 拼到一起

session 之间没法并排显示——一个 client 同时只能 attach 一个 session。要并排就把别的 session 的
面板搬过来：

```
Ctrl+a :  join-pane -h -s 其它session:0.0    # 搬到右边
Ctrl+a :  join-pane -v -s 其它session:0.0    # 搬到下面
Ctrl+a :  break-pane                          # 再拆出去独立成 window
```

### 其它设定

- 默认 shell 由模板的 `{{ lookPath "zsh" }}` 在 apply 时解析：桌面是 Homebrew 的，服务器是
  `/usr/bin/zsh`。**不能写死** —— tmux 遇到不存在的 shell 会静默回退到 sh，不报错
- `Ctrl+a f`（sesh 会话切换）的 `run-shell` 起的是非登录 shell，拿不到 `.zshrc` 里的 PATH，
  所以配置里显式补了 `~/.local/bin`、Homebrew、`~/.fzf/bin` 三个候选目录。PATH 里不存在的
  目录会被忽略，因此同一份配置三端通用
- 鼠标开启：点击切面板、拖边框调大小、滚轮翻历史
- 历史 50000 行
- 关掉 window 后自动重新编号（`renumber-windows on`）
- `xterm-256color` + truecolor override，修 VS Code 终端里的配色

---

## 踩坑记录

### tmux `default-shell` 写死路径 → 静默回退 sh

配置里写 `/home/linuxbrew/.linuxbrew/bin/zsh`，同步到服务器后那个路径不存在。tmux **不报错**，
直接回退到 sh，表现是新面板里没有提示符主题、没有别名。用模板的 `lookPath "zsh"` 在 apply
时解析本机真实路径。

### oh-my-zsh 主题和 starship 打架

VPS 上 `ZSH_THEME="robbyrussell"` 和 `eval "$(starship init zsh)"` 同时存在，两个提示符互相
覆盖。正解是 `ZSH_THEME=""` 留空，让 starship 完全接管。

### 全量 `chezmoi apply` 会踩掉机器专属配置

仓库里的 `.bashrc` / `.zshrc` 长期只有桌面那一份。在 VPS 上跑全量 apply 会丢掉它的
`$HOME/go/bin`、doppler/hermes 配置。同步到异构机器时**先 `chezmoi diff` 看清楚**，或者只
apply 明确要同步的路径：`chezmoi apply ~/.zshrc ~/.tmux.conf ~/bin`。

`.bashrc` 目前**仍未模板化**，VPS 那份还是脱管状态。

### 通过 ssh 跑 `chezmoi apply` 卡在无 TTY

目标文件本地有改动时，chezmoi 想弹交互确认，但 ssh 会话没有 TTY：

```
chezmoi: .zshrc: could not open a new TTY: open /dev/tty: no such device or address
```

先备份再加 `--force`。整个 apply 是**遇错即停**的，所以一个不存在的父目录（比如 `~/.config`）
会让后面所有文件都不生效 —— 上面那次就是 `.config` 缺失导致 `.zshrc` / `.tmux.conf` 全没写进去。

### 境内机器：慢的是 release 下载，不是 github 本身

阿里云上 `github.com` 首页 0.3s 就通，容易误判成"网络没问题"。但二进制走的是
`objects.githubusercontent.com`，被限速到 45 秒只下 831KB。

镜像可解，实测 `ghfast.top` 和 `gh-proxy.com` 都能满速拉 5MB（`ghproxy.net` 超时）：

```bash
curl -fsSL -o x.tgz https://ghfast.top/https://github.com/OWNER/REPO/releases/download/vX/ASSET
git clone --depth=1 https://ghfast.top/https://github.com/ohmyzsh/ohmyzsh.git ~/.oh-my-zsh
```

`/releases/latest/download/<文件名>` 这个路径**要求文件名里的版本号完全正确**，猜错就 404。
先查真实资源名：

```bash
curl -sS https://api.github.com/repos/OWNER/REPO/releases/latest | jq -r '.assets[].name'
```

### starship 官方安装脚本误判 Ubuntu 为 musl

`curl https://starship.rs/install.sh | sh` 在 Ubuntu 22.04 上报 "please create an issue
requesting a build for x86_64-unknown-linux-musl" 然后失败。直接拉 gnu tarball：

```bash
curl -fsSL -o st.tgz https://ghfast.top/https://github.com/starship/starship/releases/latest/download/starship-x86_64-unknown-linux-gnu.tar.gz
tar xzf st.tgz && mv starship ~/.local/bin/
```

### 通过 ssh 传嵌套 `$(...)` 的安装脚本不稳

`ssh host 'sh -c "$(curl -fsSL .../install.sh)" "" --unattended'` 这种多层引号嵌套经 ssh
传过去经常静默失败。而且脚本开头如果有 `set -e`，第一步失败会让**后面所有 echo 都不输出**，
看起来像"命令没跑"。改成直接 `git clone` 或分步执行，报错才看得见。

### apt 里的 zoxide 太老

Ubuntu 22.04 的 `zoxide` 是 0.4.3（当前 0.10.0），不支持 `--cmd cd`。这类快速迭代的 Rust
CLI 一律拉 release 二进制，别用 apt。
