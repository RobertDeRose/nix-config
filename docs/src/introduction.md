# Maison

Maison is a mise-driven workstation configuration manager for macOS and Linux. It uses Nix as the system engine, Home Manager as the dotfile deployer, and mise as its task and tool foundation.

```bash
maison tasks
maison doctor
maison plan
maison apply
maison check
```

The `maison` command can be run from any directory. All hosts are explicit in `inventory.toml`; ordinary package lists are in `packages.toml`; application settings are native files under `dotfiles/`. Darwin uses nix-darwin and Linux uses system-manager plus Home Manager.
