# Module Composition

The configuration is composed from layered Nix modules. Each layer adds to the
previous one, and Nix's module system merges lists and attribute sets automatically.

## System Modules (macOS)

```
modules/darwin/system.nix      macOS defaults (Dock, Finder, keyboard, trackpad)
modules/darwin/apps.nix        Homebrew casks/brews/masApps + nix system packages
modules/darwin/iterm2.nix      Declarative iTerm2 plist management
modules/common/cache.nix       Shared binary cache URLs and public keys
modules/darwin/config.nix      nix-darwin Nix daemon, GC, experimental features
modules/darwin/fonts.nix       Nerd Fonts, Font Awesome, Material Design Icons
```

These make up the Darwin system layer for every macOS host. `flake.nix` imports
`modules/darwin/config.nix`, `modules/darwin/system.nix`, `modules/darwin/apps.nix`,
and `modules/darwin/iterm2.nix`; `config.nix` and `system.nix` then pull in the
shared cache data and font packages. A host's `default.nix` can set any of the same
options to add packages, change defaults, or enable features like the linux-builder.

## System Modules (Linux)

```
modules/common/cache.nix       Shared binary cache URLs and public keys
modules/linux/system.nix       system-manager: SSH hardening, users, packages,
                               locale, Nix substituter config
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
home/common/herdr.nix          Herdr terminal multiplexer
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

## Adding Packages from Flake Inputs

Some tools are provided by external flake inputs (e.g. `llmagents`) rather than
nixpkgs. When a tool has a home-manager module (`programs.<name>`), create a
module like `home/common/opencode.nix`:

```nix
{ pkgs, inputs, ... }:
let
  pkg = inputs.llmagents.packages.${pkgs.stdenv.hostPlatform.system}.opencode;
in
{
  programs.opencode = {
    enable = true;
    package = pkg;
  };
}
```

When a tool does **not** have a home-manager module, add it to `home.packages`
directly instead, like `home/common/herdr.nix`:

```nix
{ pkgs, inputs, ... }:
{
  home.packages = [
    inputs.llmagents.packages.${pkgs.stdenv.hostPlatform.system}.herdr
  ];
}
```

In both cases, the package must be exposed in `flake.nix` under `perSystem.packages`
from the appropriate input, and the module must be imported in
`home/common/default.nix`. The `inputs` special arg is made available to
home-manager modules via `home-manager.extraSpecialArgs.inputs = inputs` in
`flake.nix`.
