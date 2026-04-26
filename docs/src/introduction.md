# nix-config

Reproducible system configuration for **macOS** and **Linux** using
[Nix flakes](https://nixos.wiki/wiki/Flakes),
[nix-darwin](https://github.com/LnL7/nix-darwin),
[system-manager](https://github.com/numtide/system-manager), and
[home-manager](https://github.com/nix-community/home-manager).

Built on [flake-parts](https://flake.parts) with
[easy-hosts](https://github.com/tgirlcloud/easy-hosts) for auto-discovered
host management. Tasks are managed with [mise](https://mise.jdx.dev).

## Platforms

| Platform | System Config | User Config | Package Manager |
|----------|--------------|-------------|-----------------|
| macOS (Apple Silicon) | nix-darwin | home-manager | Homebrew + Nix |
| macOS (Intel) | nix-darwin | home-manager | Homebrew + Nix |
| Ubuntu Linux (headless) | system-manager | home-manager | Nix |

## Quick Start

Bootstrap a fresh machine with a single command:

```bash
sh -c 'curl -sSfL https://raw.githubusercontent.com/RobertDeRose/nix-config/main/bootstrap.sh | bash -s -- <hostname>'
```

Or from a local clone:

```bash
./bootstrap.sh <hostname>
```

See [Bootstrapping](./operations/bootstrapping.md) for details.

## Key Design Decisions

- **No flake.nix editing to add hosts** -- drop a directory into `hosts/` and it's
  auto-discovered.
- **Shared modules, per-host overrides** -- global config in `modules/` and `home/`,
  host-specific additions in `hosts/<arch>-darwin/<hostname>/` or
  `systems/<arch>-linux/<hostname>/`.
- **Declarative Homebrew** -- casks, brews, and Mac App Store apps are managed via Nix
  and cleaned up automatically.
- **Consistent Ayu Mirage theme** -- terminal, editor, multiplexer, and prompt all share
  the same color palette.
