# Module Reference

Quick reference for what each module provides.

## System Modules

### `modules/common/nix-core.nix`

Nix daemon settings shared across platforms. Configures experimental features
(`nix-command`, `flakes`), binary caches, trusted users, and weekly garbage
collection. Selects Lix or CppNix based on platform.

### `modules/common/fonts.nix`

Font packages installed system-wide: Nerd Fonts (DejaVu Sans Mono, Fira Code,
Meslo LG, Symbols Only), Font Awesome, and Material Design Icons.

### `modules/common/overlays.nix`

Temporary nixpkgs overrides. Currently:

- Disables direnv tests (fail under macOS SIP sandbox)
- Replaces `mas` with version 6.0.1 (required by Homebrew, not yet in nixpkgs)

### `modules/darwin/system.nix`

macOS system defaults: Dock (autohide, persistent apps, hot corners), Finder
(Posix path in title, list view, show extensions), Trackpad (tap-to-click,
three-finger drag), Keyboard (Caps Lock remapped to Escape), security
(TouchID + WatchID for sudo), timezone.

### `modules/darwin/apps.nix`

Declarative package management: nix system packages (bat, eza, git, fastfetch,
devenv), Homebrew taps, brews, casks, and Mac App Store apps. Uses `zap`
cleanup to remove anything not listed.

### `modules/darwin/iterm2.nix`

Copies the exported iTerm2 plist to a nix-managed location on activation.
The plist is stored as a binary file in `config/iterm2/`.

### `modules/linux/system.nix`

system-manager config for headless Ubuntu: hostname, timezone, locale, SSH
hardening (password auth disabled, root login disabled), GitHub-based SSH
authorized keys with caching, system packages, and user creation with zsh
shell.

## Home-Manager Modules

### `home/common/core.nix`

Cross-platform CLI tools including `btop`, `jq`, `openspec`, `pstree`,
`ripgrep`, `tmux`, `yazi`, `yq`, and repo helper scripts (`rund`, `gwt`,
`gcb`). Sets Helix as the default editor outside Zed-integrated terminals.

### `home/common/shell.nix`

Zsh with autosuggestions and syntax highlighting. Starship prompt with Ayu
Mirage colors and Nerd Font pill segments. Navigation aliases, git shortcuts,
double-Escape sudo toggling, `mise activate zsh`, and platform-aware PATH setup.

### `home/common/git.nix`

Git config with SSH commit signing (ed25519), difftastic as diff tool, merge
style zdiff3, pull rebase, and conditional includes for per-workspace identity.
GitHub CLI with credential helper. Lazygit.

### `home/common/direnv.nix`

direnv + nix-direnv for automatic Nix shell activation. Custom mise integration
script that sources mise without pulling the package into the Nix closure.

### `home/common/helix.nix`

Helix editor: Ayu Mirage theme, relative line numbers, rulers at 100/120 chars.
Keybindings matching VSCode conventions. Language servers: harper-ls (grammar),
marksman, markdown-oxide, rumdl.

### `home/common/zellij.nix`

Zellij terminal multiplexer with Ayu Mirage theme, compact layout. Platform-aware
clipboard: `pbcopy` on macOS, OSC52 escape sequence on Linux.

### `home/common/ghostty.nix`

Ghostty terminal (macOS only): Ayu Mirage theme, DejaVu SansM Nerd Font size 16,
quick terminal panel (top, 35% height). Package set to null (installed via
Homebrew).

### `home/common/zed.nix`

Zed editor config (macOS only): package managed outside Nix, theme set to Ayu
Mirage, VSCode keymap with Helix mode, Copilot edit predictions, and custom
keybindings matching Helix.

### `home/common/opencode.nix`

OpenCode AI coding agent. Uses the `opencode` flake input, currently backed by
Numtide's `llm-agents.nix`, so the package can come from `cache.numtide.com`
without rebuilding the upstream Bun workspace locally.

### `home/darwin/ssh.nix`

macOS SSH client using Bitwarden Desktop as the SSH agent. Configures
`IdentityAgent` to the Bitwarden sandbox socket path.
