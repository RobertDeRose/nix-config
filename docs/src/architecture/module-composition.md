# Module composition

Hosts select a small list of intent-oriented profiles in `inventory.toml`:

```toml
profiles = ["base", "dev", "mac"]
```

`nix/lib/profiles.nix` maps each profile to explicit Darwin, Linux, and Home Manager module lists. Constructors select only module classes appropriate for the host system and append optional `hosts/<hostname>/system.nix` or `home.nix` exceptions.

```text
host record
  └─► selected profiles
        ├─► darwinModules
        ├─► linuxModules
        └─► homeModules
```

Reusable implementation lives under `nix/modules/`; profiles compose it rather than duplicate it. Package lists merge from `packages.toml`, while packages tightly coupled to a module remain with that module and are audited under `[module_owned]`.
