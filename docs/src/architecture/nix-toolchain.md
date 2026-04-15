# Nix Toolchain

## Lix vs CppNix

This repo uses [Lix](https://lix.systems) (a Nix fork) on most platforms for
its improved error messages and performance. The exception is **x86_64-darwin**
(Intel Macs), where Lix dropped support -- those machines use the upstream
CppNix package instead.

The selection logic lives in `modules/common/nix-core.nix`:

```nix
nix.package =
  if pkgs.stdenv.hostPlatform.system == "x86_64-darwin"
  then pkgs.nix
  else pkgs.lix;
```

## Experimental Features

The flake enables `nix-command` and `flakes` experimental features globally.
These are required for `nix build`, `nix develop`, and flake-based workflows.

## Binary Caches

Three substituters are configured to speed up builds:

| Cache | Purpose |
|-------|---------|
| `cache.nixos.org` | Official NixOS cache |
| `nix-community.cachix.org` | Community packages (home-manager, etc.) |
| `cache.numtide.com` | numtide packages (system-manager) |

## Garbage Collection

Automatic weekly GC deletes store paths older than 7 days:

```nix
nix.gc = {
  automatic = true;
  options = "--delete-older-than 7d";
};
```

Manual GC is available via `mise gc` (aggressive) and `mise clean` (remove old
generations).
