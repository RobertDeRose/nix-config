# Shell & Prompt

The shell configuration lives in `home/common/shell.nix` and provides a
consistent experience across macOS and Linux.

## Zsh

Zsh is the default shell with these plugins:

- **zsh-autosuggestions** -- fish-like history suggestions
- **zsh-syntax-highlighting** -- command syntax coloring

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
| `gst`, `gd`, `ga`, `gc`... | git shortcuts | Common git operations |
| `docker` | `container` | macOS only (Apple container runtime) |
| `up N` | `cd ../../../...` | Navigate up N directories |

Per-host aliases go in `hosts/<arch>/<hostname>/home.nix` -- see
[Per-Host Overrides](./per-host-overrides.md).

## Platform-Aware Behavior

- macOS adds `/opt/homebrew/bin` and `/opt/homebrew/sbin` to `$PATH`
- The `docker` alias only applies on Darwin (maps to Apple's `container` runtime)
- Ghostty shell integration is sourced manually (workaround for cmux)
