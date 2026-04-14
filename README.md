# TIMHX Dotfiles

> Personal dotfiles for a streamlined terminal environment on Linux/macOS.

## What's Inside

| File | Description |
|------|-------------|
| `dot_bashrc` | Bashrc with history tuning, window-size checking, and lesspipe |
| `dot_zshrc` | Zsh config powered by [Oh My Zsh](https://github.com/ohmyzsh/ohmyzsh) (robbyrussell theme) |
| `dot_tmux.conf` | Tmux config with mouse support, Chinese right-click menu, and automatic window renumbering |
| `dot_fzf.bash` | Fzf path and bash integration |
| `dot_config/nvim/` | [LazyVim](https://lazyvim.github.io/) Neovim config — clipboard `unnamedplus`, lazy-lock, and plugin autocmds/keymaps |

## Quick Install

```bash
# Clone the repo
git clone https://github.com/TIMHX/dotfiles.git ~/.dotfiles
cd ~/.dotfiles

# Symlink everything
ln -sf ~/.dotfiles/dot_bashrc   ~/.bashrc
ln -sf ~/.dotfiles/dot_zshrc     ~/.zshrc
ln -sf ~/.dotfiles/dot_tmux.conf ~/.tmux.conf
ln -sf ~/.dotfiles/dot_fzf.bash ~/.fzf.bash
ln -sf ~/.dotfiles/dot_config/nvim ~/.config/nvim

# Reload
source ~/.bashrc      # or source ~/.zshrc
tmux source-file ~/.tmux.conf
```

## Tmux Highlights

- **Mouse mode** — click to switch panes, resize, and scroll logs
- **Right-click menu** — split panes, zoom, close with confirmation
- **Auto renumber** — windows stay tidy after closing one
- **Same-path splits** — new panes open in the current directory
- **Xterm-256color** — proper color support (including VS Code)

## Neovim (LazyVim)

Uses [LazyVim](https://lazyvim.github.io/) with:
- Clipboard integration (`unnamedplus`)
- Auto-install of lazy.nvim plugins on first launch
- `lua/plugins/`, `lua/config/` structure for custom additions

```bash
# First launch — LazyVim auto-installs all plugins
nvim
```

## Requirements

- **Neovim** ≥ 0.9 (with Lua support)
- **Tmux** ≥ 3.0
- **Oh My Zsh** (for zshrc theme)
- **Fzf** (for fzf integration)
- **Node.js** (for LazyVim extras / mason)

## Auto-Update

Commits are auto-generated with timestamps. To sync your own changes:

```bash
cd ~/.dotfiles
git add -A
git commit -m "Update: $(date '+%Y-%m-%d %H:%M:%S')"
git push
```
