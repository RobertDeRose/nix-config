# Module Composition

The configuration is composed from layered Nix modules. Each layer adds to the
previous one, and Nix's module system merges lists and attribute sets automatically.

## System Modules (macOS)

```
modules/darwin/system.nix      macOS defaults (Dock, Finder, keyboard, trackpad)
modules/darwin/apps.nix        Homebrew casks/brews/masApps + nix system packages
modules/darwin/iterm2.nix      Declarative iTerm2 plist management
modules/common/nix-core.nix    Nix daemon, caches, GC, experimental features
modules/common/fonts.nix       Nerd Fonts, Font Awesome, Material Design Icons
modules/common/overlays.nix    Temporary nixpkgs patches
```

These are imported by `flake.nix` for every Darwin host. A host's `default.nix`
can set any of the same options to add packages, change defaults, or enable features
like the linux-builder.

## System Modules (Linux)

```
modules/linux/system.nix       system-manager: SSH hardening, users, packages, locale
modules/common/nix-core.nix    Shared Nix daemon settings
modules/common/fonts.nix       Shared fonts
```

## Home-Manager Modules

```
home/common/default.nix        Aggregator -- imports all shared modules below
home/common/core.nix           Cross-platform CLI tools and repo helper scripts
home/common/shell.nix          zsh + starship prompt + aliases
home/common/git.nix            git, gh, lazygit, SSH signing, difftastic
home/common/direnv.nix         direnv + nix-direnv + mise integration
home/common/helix.nix          Helix editor + LSPs
home/common/zellij.nix         Zellij multiplexer
home/common/htop.nix           htop layout
home/common/opencode.nix       OpenCode AI agent
home/common/ghostty.nix        Ghostty terminal (macOS only, imported by home/darwin.nix)
home/common/zed.nix            Zed editor config (macOS only, imported by home/darwin.nix)
```

`home/darwin.nix` and `home/linux.nix` are the platform entry points. They import
`common/` plus platform-specific modules.

## Merge Behavior

Nix module options like `homebrew.brews`, `environment.systemPackages`,
`home.packages`, and `home.shellAliases` are list or attrset types that **merge
across modules**. This means a host's `default.nix` or `home.nix` can simply set:

```nix
homebrew.brews = [ "mosquitto" ];
```

and it will be added to the global list -- no need to modify `apps.nix`.
