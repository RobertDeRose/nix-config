# Nix Toolchain

## Nix implementations

This repo uses upstream [Nix](https://nixos.org/) (CppNix) on all supported
platforms. Darwin selects the package explicitly in
`modules/darwin/config.nix`:

```nix
nix.package = pkgs.nix;
```

Linux bootstrap and deployment also use the official upstream Nix installer.
To switch the Nix implementation on an existing Mac, change `nix.package` and
run `mise run nix:switch`. Don't use `mise run nix:uninstall` for that: a full
uninstall deletes the APFS Nix store and every generation.

## Experimental Features

The flake enables `nix-command` and `flakes` experimental features globally.
These are required for `nix build`, `nix develop`, and flake-based workflows.

## Binary Caches

Four substituters are configured to speed up builds:

| Cache | Purpose |
|-------|---------|
| `cache.nixos.org` | Official NixOS cache |
| `nix-community.cachix.org` | Community packages (home-manager, etc.) |
| `cache.numtide.com` | numtide packages (system-manager) |
| `robertderose.cachix.org` | Personal cache (pre-built config derivations) |

## Garbage Collection

Automatic weekly GC deletes store paths older than 7 days:

```nix
nix.gc = {
  automatic = true;
  options = "--delete-older-than 7d";
};
```

Manual cleanup is available via `mise run nix:clean [window]` (prune old
system generations for this config) and `mise run nix:gc` (aggressive
store-wide garbage collection).
