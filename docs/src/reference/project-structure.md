# Project structure

```text
flake.nix                 Inputs and output delegation
inventory.toml            Users, hosts, systems, profiles, features
packages.toml             Data-driven package ownership
mise.toml                 Tool versions and `.mise/tasks` discovery
.mise/tasks/              Executable task interface
.mise/lib/                Shared implementation
nix/lib/                  Inventory, validation, profiles, constructors
nix/profiles/             Intent-oriented composition
nix/modules/              Low-level platform and Home Manager modules
hosts/<hostname>/         Optional exceptions only
dotfiles/                 Native application configuration
tests/tasks/              Task/library regression tests
```
