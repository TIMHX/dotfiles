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

## tmux

前缀键改成了 **`Ctrl+a`**（默认的 `Ctrl+b` 已解绑）。下面所有快捷键都是「先按 `Ctrl+a`，松开，再按后一个键」。

配置：`dot_tmux.conf` → `~/.tmux.conf`
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

- 默认 shell 指向 `/home/linuxbrew/.linuxbrew/bin/zsh`（**不是** `/bin/zsh`，那个路径在本机不存在，
  tmux 遇到无效 shell 会静默回退）
- 鼠标开启：点击切面板、拖边框调大小、滚轮翻历史
- 历史 50000 行
- 关掉 window 后自动重新编号（`renumber-windows on`）
- `xterm-256color` + truecolor override，修 VS Code 终端里的配色
