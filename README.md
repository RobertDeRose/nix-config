# Maison

Maison is a two-layer macOS and Linux configuration repository:

- **Nix/Lix owns operating-system state.** nix-darwin configures macOS; system-manager configures non-NixOS Linux.
- **mise owns user state.** It installs tools, ordinary Homebrew bottles and casks, Mac App Store applications, user preferences, and dotfiles.

Home Manager is intentionally absent. `nh` provides the local nix-darwin workflow, and `deploy-rs` provides remote system-manager deployment and connection-aware rollback.

## Ownership boundary

| Nix/Lix | mise |
| --- | --- |
| Nix daemon, caches, GC, and store policy | Developer tools and language runtimes |
| PAM, Apple Watch/Touch ID sudo, sudoers | Ordinary Homebrew formulae and casks |
| Hostname, timezone, locale, users | Mac App Store applications |
| Root-owned files and SSH daemon policy | Git, SSH client, Zsh, Starship, editors |
| System launchd/systemd services | User LaunchAgents/systemd units |
| Machine-wide or privileged macOS policy | Current-user macOS preferences |
| System-wide fonts and OS-integrated installers | User dotfiles and Tera templates |

A file, package, service, or preference must have exactly one owner.

## Common commands

```bash
maison doctor
maison plan
maison apply
maison update

maison system plan
maison system apply
maison system history
maison system rollback
maison system clean

maison user plan
maison user apply
maison user status
maison user update

maison deploy dev-som
```

The same commands are available as mise tasks, for example `mise run system:plan`.

`maison apply` performs two sequential transactions:

1. Activate the Nix system configuration.
2. Converge the mise user environment.

The user transaction is not part of the Nix generation and is not rolled back by `maison rollback`.

## Flake outputs

```text
darwinConfigurations.<host>   nix-darwin system closure
systemConfigs.<host>           system-manager system closure
deploy.nodes.<host>            deploy-rs Linux deployment
packages.<system>.nh           local system UX
packages.<system>.deploy-rs    remote system deployment
```

There are no `homeConfigurations` outputs.

## Configuration layout

```text
flake.nix                     system inputs
inventory.toml                users, hosts, profiles, deploy endpoints
nix/                          OS-level modules and deployment definitions
config/mise/                  global user tools, packages, and preferences
dotfiles/                     native user configuration files
.mise/tasks/system/           Nix/nh/deploy-rs workflows
.mise/tasks/user/             mise bootstrap workflows
scripts/                      idempotent user migration/finalization helpers
```

Platform-specific mise files are selected with `.miserc.toml` and `auto_env = true`:

- `config.macos.toml`: current-user macOS preferences.
- `config.macos-arm64.toml`: Apple Silicon user-facing Homebrew formulae, casks, and MAS applications.
- `config.macos-x64.toml`: documents the unsupported built-in Homebrew backend boundary.
- `config.linux.toml`: Linuxbrew user packages and locale.

## Bootstrap

From an existing checkout:

```bash
./bootstrap.sh --host "$(hostname -s)"
```

The bootstrap installs mise and Nix/Lix when missing, applies the Nix system layer, then applies user state.

Before the first real switch on an existing machine:

```bash
maison check
maison system plan
maison user plan
```

Review `docs/migration-contract.md` before deleting old generations or backups.

## Important guarantees and limits

- Apple Watch, Touch ID, and `pam-reattach` remain declarative nix-darwin policy.
- deploy-rs rollback protects the Linux **system** profile; it does not roll back mise user changes.
- mise defaults are limited to current-user preferences. Privileged and machine-wide defaults stay in Nix.
- mise's built-in Homebrew backend is used for ordinary user software on Apple Silicon macOS and Linux. Native Homebrew remains Nix-owned only for OS-integrated FUSE-T packages; Intel macOS requires a separately chosen user-package fallback.
- The initial migration keeps `.previous` during remote repository replacement and preserves targeted backups under `~/.local/state/maison/backups`.

See the [architecture](docs/architecture.md), [migration contract](docs/migration-contract.md), and [recovery guide](docs/recovery.md).
