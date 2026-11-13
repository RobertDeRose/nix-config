# Shell & Prompt

The shell configuration lives in `home/common/shell.nix` and provides a
consistent experience across macOS and Linux.

## Zsh

Zsh is the default shell with Home Manager-managed Oh My Zsh and these plugins:

- **Oh My Zsh `git`** -- the full Git alias/function set
- **Oh My Zsh `sudo`** -- `Esc Esc` toggles or edits a command as root
- **Oh My Zsh `colored-man-pages`**, `command-not-found`, `extract`, `safe-paste`, `z`, and `brew`
- **zsh-autosuggestions** -- fish-like history suggestions
- **zsh-syntax-highlighting** -- command syntax coloring

The Oh My Zsh prompt theme is disabled because a native Zsh prompt owns the
prompt. Home Manager owns mise, fzf, and worktrunk; those are intentionally not
loaded again as Oh My Zsh plugins.

It also restores a few interactive behaviors that changed after the move to
Home Manager-managed zsh:

- `Delete` performs forward delete instead of inserting `~`
- `Up` and `Down` search history by the current typed prefix
- `Ctrl-W` uses bash-style word boundaries
- `Tab` uses Zsh completion directly instead of Fzf's optional `**` wrapper
- `~/.zshrc.local` is sourced if present for machine-local shell experiments

Mise refreshes automatically when the working directory changes, rather than
launching a subprocess after every command. After editing an active mise
configuration in place, use `cd .` (or open a new shell) to apply it.

## Prompt

Zsh renders its prompt natively in `shell.nix`; only Git status runs an external
process. The prompt shows:

| Segment | What it displays |
|---------|-----------------|
| OS icon | macOS/Linux logo |
| User | Current user name |
| Directory | Current path (last 2 levels) |
| Git | Branch, staged/modified/untracked/conflict flags, ahead/behind, stashes |
| Duration | Command execution time (if at least 0.5 seconds) |
| Time | HH:MM format |

[Starship](https://starship.rs) with the Maison theme
(`dotfiles/starship/maison.toml`) drives the Bash prompt only.

## Aliases

Global aliases defined in `shell.nix`:

| Alias | Command | Notes |
|-------|---------|-------|
| `ls` | `eza` | Directory listing with icons |
| `cat`, `less` | `bat` | Syntax-highlighted pager |
| `gst`, `gd`, `ga`, `gc`... | git shortcuts | Common git operations |
| `up N` | shell function | Navigate up N directories |
| `..` and `up N` | `up 1` / `cd ../../..` | Convenience directory navigation |

Per-host aliases go in `hosts/<arch>-darwin/<hostname>/home.nix` or
`systems/<arch>-linux/<hostname>/home.nix` -- see
[Per-Host Overrides](./per-host-overrides.md).

## CLI Helpers

Repo-managed helper scripts installed from `files/scripts/`:

| Script | Purpose |
|--------|---------|
| `rund` | Run a disposable Ubuntu container with the current directory mounted in |

Shell functions defined in `shell.nix`:

| Function | Purpose |
|----------|---------|
| `lab <host>` | Open `ssh root@<host>`. If root doesn't accept your key yet, first log in as `service`, `su` to root (prompts for the root password), and append your public key to `/root/.ssh/authorized_keys` |
| `ggrep` | `git grep` excluding SVG, minified, and vendored assets |

`lab` takes the key from `ssh-add -L` (the Bitwarden SSH agent on macOS) and asks
which to use when the agent holds several. Set `LAB_SSH_PUBKEY` to a `.pub`
file to use that instead.

Packaged Git workflow tools installed via Home Manager:

| Tool | Purpose |
|------|---------|
| `wt` | Worktrunk worktree management with shell integration |
| `git trim` | Trim tracking branches merged or gone upstream |

Git worktree management is now provided by Worktrunk via the `wt` command and
its shell integration configured in `home/common/default.nix`.

## Platform-Aware Behavior

- macOS adds `/opt/homebrew/bin` and `/opt/homebrew/sbin` to `$PATH`
- `Esc Esc` uses the Oh My Zsh sudo widget
- `mise activate zsh` is loaded when available, with environment refreshes on directory changes
- Ghostty shell integration is sourced manually (workaround for cmux)
- The filtered Git grep helper is `ggrep` (Oh My Zsh owns `gg`)

Home Manager must be the only manager of `~/.zshrc`; do not also map that file
from Maison's mise dotfile configuration.
