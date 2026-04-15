# Architecture Overview

This repo manages two distinct platform configurations through a unified Nix
flake. The architecture splits into three layers:

1. **System configuration** -- OS-level settings, packages, services, and daemons.
2. **User configuration** -- dotfiles, shell, editor, and CLI tools via home-manager.
3. **Host discovery** -- automatic detection of host directories without manual flake
   registration.

## Platform Split

**macOS** uses [nix-darwin](https://github.com/LnL7/nix-darwin) for system config.
Home-manager runs as a nix-darwin module, so a single `darwin-rebuild switch` applies
both system and user changes.

**Linux** (Ubuntu headless servers) uses
[system-manager](https://github.com/numtide/system-manager) for system config and
home-manager as a standalone tool. These are applied separately because system-manager
is not NixOS -- it manages config files and services on an existing distro.

## Module Layers

```
flake.nix
├── modules/common/       Shared Nix settings, fonts, overlays
├── modules/darwin/        macOS system defaults, Homebrew, iTerm2
├── modules/linux/         system-manager SSH, users, packages
├── home/common/           Cross-platform: shell, git, editors, tools
├── home/darwin.nix        macOS-specific: Ghostty, Zed, SSH agent
├── home/linux.nix         Linux-specific: XDG dirs
└── hosts/<arch>/<name>/   Per-host overrides
```

See the sub-pages for details on each layer.
