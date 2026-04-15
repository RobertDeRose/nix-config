# Host Discovery

Hosts are auto-discovered from the filesystem. No manual registration in
`flake.nix` is needed.

## macOS Hosts (easy-hosts)

[easy-hosts](https://github.com/tgirlcloud/easy-hosts) scans
`hosts/<arch>/<hostname>/` directories and generates `darwinConfigurations`
entries automatically.

```
hosts/
├── aarch64-darwin/
│   └── USMBDEROSER/        ← auto-discovered as darwinConfigurations.USMBDEROSER
│       ├── default.nix     ← system config (required)
│       ├── user.nix        ← username + email (required)
│       └── home.nix        ← per-host HM overrides (optional)
└── x86_64-darwin/
    └── <hostname>/
        ├── default.nix
        ├── user.nix
        └── home.nix
```

The `default.nix` must import `user.nix` and wire up `_module.args` and
`home-manager.extraSpecialArgs` so the username is available throughout the config.
See [Adding a Host](../customization/adding-a-host.md) for the full walkthrough.

## Linux Hosts (custom discovery)

Linux hosts use a similar directory convention under `systems/`:

```
systems/
├── x86_64-linux/
│   └── <hostname>/
│       ├── system.nix      ← system-manager config
│       ├── user.nix        ← username + email
│       └── home.nix        ← per-host HM overrides (optional)
└── aarch64-linux/
    └── <hostname>/
        └── ...
```

easy-hosts assumes all `*-linux` directories are NixOS, but these are Ubuntu
machines using system-manager. So `flake.nix` contains custom logic to scan
`systems/` and generate `systemManagerConfigurations` + `homeConfigurations`.

## Why Two Directories?

The split between `hosts/` (Darwin) and `systems/` (Linux) exists because
easy-hosts would try to create NixOS configurations for Linux directories
under `hosts/`. Keeping them separate avoids this conflict.

## Branch Strategy

Host directories are typically developed on feature branches named
`host/<hostname>` and merged to `main` once tested. This keeps `main` clean
while allowing per-machine iteration.
