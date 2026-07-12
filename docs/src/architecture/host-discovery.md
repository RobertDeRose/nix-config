# Host inventory

Hosts are not discovered from directory names. `inventory.toml` is the sole host/user metadata source and is validated by both shell tasks and Nix evaluation.

```toml
[hosts.example]
system = "aarch64-darwin"
user = "rderose"
profiles = ["base", "developer", "mac-desktop"]
```

Optional exceptions live in `hosts/<hostname>/system.nix` and `hosts/<hostname>/home.nix`. The constructors in `nix/lib/` preserve `darwinConfigurations.<host>`, `systemConfigs.<host>`, and `homeConfigurations.<host>`.
