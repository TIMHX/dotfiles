# TIMHX Dotfiles

> Personal dotfiles managed by [chezmoi](https://www.chezmoi.io/) — the multi-machine dotfile manager you'll actually enjoy using.

## What is chezmoi?

[chezmoi](https://www.chezmoi.io/) is a dotfile manager that:
- Keeps your dotfiles in a **dedicated Git repo** (source of truth)
- Safely **merges** per-machine overrides (not just your dotfiles — your `~/bin/` too)
- Lets you use **templates** (`{{ .chezmoi.username }}`) for machine-specific values
- Leaves the actual dotfiles in your `$HOME` clean and auto-managed

Your dotfiles **are** the chezmoi source directory. chezmoi applies them to `$HOME` on any machine.

---

## What's Inside

| File | Description |
|------|-------------|
| `dot_bashrc` | Bash config — history, starship prompt, Homebrew, zoxide, NVM, Doppler/AI tool aliases |
| `dot_zshrc` | Zsh config — Oh My Zsh (robbyrussell), same toolchain as bashrc |
| `dot_tmux.conf` | Tmux — mouse support, Chinese right-click menu, auto renumber, xterm-256color |
| `dot_fzf.bash` | Fzf path and bash integration |
| `dot_config/nvim/` | [LazyVim](https://lazyvim.github.io/) Neovim config — clipboard `unnamedplus`, autocmds, keymaps |

---

## Quick Install

```bash
# 1. Install chezmoi (one-liner)
brew install chezmoi   # macOS/Linux
# or: curl -sfL https://get.chezmoi.io | sh

# 2. Clone and apply dotfiles in one shot
chezmoi init --apply https://github.com/TIMHX/dotfiles.git

# 3. Reload your shell
exec $SHELL
```

That's it. chezmoi pulls the repo, copies/symlinks everything to `$HOME`, and you're set.

---

## Daily Workflow — `czp` and `cza`

These are the two aliases you use every day (defined in `dot_zshrc`):

### `cza <path>` — Add a file to dotfiles

```bash
cza ~/.config/nvim/init.lua   # chezmoi add + auto-sync to GitHub
```

What it does:
1. `chezmoi add ~/.config/nvim/init.lua` — stages the file into the chezmoi source directory
2. `czp` — auto-commits and pushes to GitHub

### `czp` — Sync dotfiles to GitHub

```bash
czp
# 🔄 Syncing local changes to source...
# 🧐 Current changes in source directory:
#  M dot_zshrc
# ⚠️  Do you want to commit and push these changes? (y/n)
```

What it does:
1. `chezmoi re-add` — rescans `$HOME` and re-stages any changed files into the source dir
2. Shows you a diff of what changed
3. Prompts for confirmation
4. Git commits with timestamp + pushes to `origin/main`

### `czu` — Pull latest from GitHub

```bash
czu   # chezmoi update — pulls and applies on current machine
```

### `t` — Session picker (Zsh only)

```bash
t     # Opens fzf session picker → sesh connect
```

---

## Tmux Highlights

- **Mouse mode** — click to switch panes, resize, scroll logs
- **Right-click menu** — split panes, zoom, close with confirmation
- **Auto renumber** — windows stay tidy after closing one
- **Same-path splits** — new panes open in the current directory
- **Xterm-256color** — proper color support (including VS Code)

---

## Neovim (LazyVim)

Uses [LazyVim](https://lazyvim.github.io/) with:
- Clipboard integration (`unnamedplus`)
- Auto-install of lazy.nvim plugins on first launch
- `lua/plugins/`, `lua/config/` structure for custom additions

```bash
nvim   # First launch — LazyVim auto-installs all plugins
```

---

## Requirements

| Tool | Version | Purpose |
|------|---------|---------|
| **chezmoi** | ≥ 2.0 | Dotfile management |
| **Neovim** | ≥ 0.9 | Editor |
| **Tmux** | ≥ 3.0 | Terminal multiplexer |
| **Oh My Zsh** | any | Zsh theme framework |
| **Fzf** | any | Fuzzy finder |
| **Node.js** | any | LazyVim extras / mason |
| **Homebrew** | any | Package manager |
| **Doppler** | any | Secrets + env injection |

---

## Auto-Update

Every `czp` commit is auto-timestamped. To use dotfiles on a **new machine**:

```bash
chezmoi init --apply https://github.com/TIMHX/dotfiles.git
```
