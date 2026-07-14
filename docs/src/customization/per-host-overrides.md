# Per-host overrides

Most hosts need only an `inventory.toml` entry. Add `hosts/<hostname>/system.nix` or `hosts/<hostname>/home.nix` only for a real exception. Override files must not repeat system, user, identity, or profile data.

Use `maison host:add ... --overrides` to create documented stubs, or create only the required file manually. `maison check:inventory` rejects override directories without an inventory host and unexpected files.
