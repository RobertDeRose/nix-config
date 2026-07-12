# nix-config

This repository uses Nix as the system engine, Home Manager as the dotfile deployer, and mise as the stable user-facing command interface.

```bash
mise tasks
mise run doctor
mise run plan
mise run apply
mise run check
```

All hosts are explicit in `inventory.toml`; ordinary package lists are in `packages.toml`; application settings are native files under `dotfiles/`. Darwin uses nix-darwin and Linux uses system-manager plus Home Manager.
