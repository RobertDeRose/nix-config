# Shell & Prompt

The shell configuration lives in `home/common/shell.nix` and provides a
consistent experience across macOS and Linux.

## Zsh

Zsh is the default shell with these plugins:

- **zsh-autosuggestions** -- fish-like history suggestions
- **zsh-syntax-highlighting** -- command syntax coloring

It also restores a few interactive behaviors that changed after the move to
Home Manager-managed zsh:

- `Delete` performs forward delete instead of inserting `~`
- `Up` and `Down` search history by the current typed prefix
- `Ctrl-W` uses bash-style word boundaries
- `~/.zshrc.local` is sourced if present for machine-local shell experiments

## Starship Prompt

The prompt uses [Starship](https://starship.rs) with an elaborate Ayu Mirage-themed
configuration using Nerd Font "pill" segments:

```
┌  macOS  ~/workspace/personal/nix-config   main   nix   1.2s
└
```

Each segment is color-coded and separated by Nerd Font glyphs. The prompt
shows:

| Segment | What it displays |
|---------|-----------------|
| OS icon | macOS/Linux logo |
| Directory | Current path (truncated to 3 levels) |
| Git branch | Branch name + status |
| Languages | Node, Python, Rust, Go, Java versions (when detected) |
| Duration | Command execution time (if > 2 seconds) |
| Shell | Current shell name |
| Time | HH:MM format |

## Aliases

Global aliases defined in `shell.nix`:

| Alias | Command | Notes |
|-------|---------|-------|
| `ls`, `l`, `ll`, `la` | `eza` variants | With icons and git status |
| `cat`, `less` | `bat` | Syntax-highlighted pager |
| `oc` | `opencode` | AI coding agent |
| `gcb` | `~/.local/bin/gcb` | Delete merged or squash-merged local git branches |
| `gwt` | `source ~/.local/bin/gwt` | Create or jump to a git worktree for a branch |
| `gst`, `gd`, `ga`, `gc`... | git shortcuts | Common git operations |
| `docker` | `container` | macOS only (Apple container runtime) |
| `up N` | `cd ../../../...` | Navigate up N directories |

Per-host aliases go in `hosts/<arch>-darwin/<hostname>/home.nix` or
`systems/<arch>-linux/<hostname>/home.nix` -- see
[Per-Host Overrides](./per-host-overrides.md).

## Custom Scripts

`~/.local/bin` contains repo-managed helper scripts installed from
`files/scripts/`:

| Script | Purpose |
|--------|---------|
| `rund` | Run a disposable Ubuntu container with the current directory mounted in |
| `gwt` | Create or reuse a git worktree for a branch and `cd` into it |
| `gcb` | Delete merged and squash-merged local branches against a base branch |

## Platform-Aware Behavior

- macOS adds `/opt/homebrew/bin` and `/opt/homebrew/sbin` to `$PATH`
- The `docker` alias only applies on Darwin (maps to Apple's `container` runtime)
- `Esc Esc` toggles a leading `sudo ` like the oh-my-zsh sudo plugin
- `mise activate zsh` is loaded when `mise` is available
- Ghostty shell integration is sourced manually (workaround for cmux)
