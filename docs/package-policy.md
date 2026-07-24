# Package policy

## Decision order

1. **mise tool backend** for versioned, user-scoped developer tools with prebuilt releases.
2. **mise built-in Homebrew formula** for user-facing native CLI packages and shared-library applications.
3. **Homebrew cask or MAS through mise** for ordinary user-facing macOS applications.
4. **Nix/nix-darwin** for system-wide fonts, filesystem integrations, system services, privileged activation, and Nix administration workflows.

A package does not belong in Nix merely because nixpkgs contains it.

## Current Nix packages

Darwin's system closure contains administration tools and deliberately system-owned integrations:

- `nh`
- `deploy-rs`
- `nixd`
- system-wide fonts
- FUSE-T casks through the minimal Nix-managed native Homebrew exception

Linux system-manager contains `nh`, the minimal `curl`/Git/tar user-bootstrap prerequisites, and packages embedded by system configuration and services.

## User package files

- `config/mise/config.toml`: cross-platform versioned tools.
- `config/mise/config.macos-arm64.toml`: Apple Silicon user-facing formulae, casks, and MAS apps.
- `config/mise/config.linux.toml`: Linuxbrew user packages.
- `config/mise/config.macos-x64.toml`: explicit Intel limitation, not false parity.

## Version policy

`latest` is intentional for fast-moving workstation tools and applications. Exact versions may be pinned where regressions are costly. Nix system inputs remain pinned by `flake.lock` and should be updated through `maison update`.

## Source-build policy

Prefer prebuilt release artifacts and Homebrew bottles for user software. Nix source builds are acceptable only for the small system closure or an explicitly justified system dependency. They should not be the default fallback for ordinary interactive tools.

## Mutations

```bash
maison tool add <backend:tool> [version]
maison tool remove <backend:tool[@version]>
maison package add <manager:package> [--macos]
maison package remove <manager:package> [--macos]
maison app add <cask>
maison app remove <cask>
```

Removal edits the declaration and deliberately leaves installed data in place. Pruning should be a separate, explicit operation.
