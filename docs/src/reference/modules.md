# Module reference

## Profiles

- `nix/profiles/base/`: shared Darwin/Linux wiring and common Home Manager state.
- `nix/profiles/dev/home.nix`: editor and developer integrations.
- `nix/profiles/mac/`: nix-darwin, Homebrew/MAS, fonts, terminals, and desktop state.
- `nix/profiles/linux/`: system-manager and Linux Home Manager state.

## System modules

- `nix/modules/common/cache.nix`: standard caches plus optional personal-cache data.
- `nix/modules/darwin/config.nix`: Nix/Lix selection, daemon settings, caches, GC, and trusted users.
- `nix/modules/darwin/system.nix`: macOS defaults, user, shell, PAM, timezone, and fonts.
- `nix/modules/darwin/apps.nix`: data-driven Nix, Homebrew, and MAS packages; cleanup is intentionally disabled.
- `nix/modules/darwin/iterm2.nix`: exported iTerm2 preferences deployment.
- `nix/modules/linux/system.nix`: system-manager users, sudoers, SSH, authorized keys, hostname, locale, timezone, services, and packages.

## Home Manager modules

Modules under `nix/modules/home/common/` enable Git, shell, editors, terminal tools, direnv, Pi, OpenCode, Herdr, Ghostty, and Zed. Static settings are primarily sourced from `dotfiles/`. `nix/modules/home/darwin/ssh.nix` configures the macOS Bitwarden SSH agent.

## Constructors and checks

- `nix/lib/mk-darwin-host.nix` and `mk-linux-host.nix` compose profile modules and optional host exceptions.
- `nix/lib/inventory.nix` and `validation.nix` validate structured host/user data.
- `nix/lib/packages.nix` and `resolve-package.nix` consume `packages.toml`.
- `nix/checks/` exposes inventory, ownership, and same-system host derivations through flake checks.
