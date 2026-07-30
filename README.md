# Maison

Maison is the command interface for a two-layer macOS and Linux configuration repository:

- **Nix/Lix owns operating-system state.** nix-darwin configures Apple Silicon macOS; system-manager configures supported non-NixOS Linux hosts.
- **mise owns user state.** It installs user tools, ordinary Homebrew formulae and casks, Mac App Store applications, current-user preferences, and dotfiles.

Home Manager is intentionally absent. `nh` provides the local nix-darwin workflow, while `deploy-rs` handles remote system-manager profiles and connection-aware system rollback.

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

## Supported systems

- `aarch64-darwin`
- `aarch64-linux`
- `x86_64-linux`

Intel macOS is deliberately unsupported rather than partially configured.

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

The same operations are available as mise tasks, for example `mise run system:plan`.

`maison apply` is deliberately system-first:

1. Build and activate the Nix system configuration.
2. Converge the mise user environment only after system activation succeeds.

A user-layer failure does not roll back the active Nix generation. A system-layer failure prevents the user phase from starting.

## Flake outputs

```text
darwinConfigurations.<host>   nix-darwin system closure
systemConfigs.<host>           system-manager system closure
deploy.nodes.<host>            deploy-rs Linux deployment
packages.<system>.nh           local system UX
packages.<system>.deploy-rs    remote system deployment
checks.<system>.*              inventory, host, schema, and activation checks
```

There are no `homeConfigurations` outputs.

## Configuration layout

```text
flake.nix                     system inputs
inventory.toml                users, hosts, profiles, deploy endpoints
nix/                          OS-level modules and deployment definitions
config/mise/                  global user tools, packages, preferences, locks
dotfiles/                     native user configuration files
.mise/tasks/system/           Nix/nh/deploy-rs workflows
.mise/tasks/user/             mise bootstrap workflows
scripts/                      migration, package, and deployment transactions
mise.toml                     repository tools, task discovery, and dotfile declarations
mise.lock                     locked repository development tool artifacts
```

Platform-specific mise files are selected through `.miserc.toml` and `auto_env = true`:

- `config.toml`: cross-platform tools and ordinary Homebrew formulae.
- `config.macos.toml`: macOS-only tools, including AI coding tools, plus current-user preferences.
- `config.macos-arm64.toml`: Apple Silicon casks, Mac App Store applications, and macOS-only formulae.
- `config.linux.toml`: Linux-specific package-manager and locale policy.

Repository validation tools are owned by the checkout `mise.toml`, not the global user config. Normal machine convergence does not install them unless it is run from this repository. The flake formatter reads the `nixfmt-rs` artifact from `mise.lock`, so hooks and `nix fmt` cannot drift to different formatter versions.

## Bootstrap

From an existing checkout:

```bash
./bootstrap.sh --host "$(hostname -s)"
```

Or from the public repository:

```bash
curl -fsSL https://raw.githubusercontent.com/RobertDeRose/nix-config/dev/bootstrap.sh \
  | bash -s -- --host "$(hostname -s)"
```

Bootstrap installs mise and Nix/Lix when missing, applies the Nix system layer, then applies user state. The default clone target remains `RobertDeRose/nix-config`; Maison is the command and architecture name, not a required repository rename.

Before the first real switch on an existing machine:

```bash
maison check
maison system plan
maison user plan
```

## Deployment safety

`maison deploy <host>` requires a clean working tree. It creates a revision-stamped archive from `git archive`, so `.git`, ignored files, untracked files, local credentials, and dirty edits are never transferred.

The remote repository replacement uses a privileged transaction boundary:

1. Validate that `repo_path` is a normalized descendant of `/home/<managed-user>`.
2. Allocate a root-owned transaction root on the same filesystem outside the managed user's writable home.
3. Stage the archive, rollback copy, lock, and journal under that root-owned transaction root.
4. Run `user:apply` as the managed user from the staged repository.
5. Finalize or roll back through the journaled privileged transaction state.

Maison fails closed when no safe same-filesystem root-owned transaction root is available.

Deploy-rs still owns the separate system-profile rollback boundary.

## Package convergence

Configuration mutators stage and validate candidate files before replacing repository state. `tool:add`, `package:add`, `app:add`, and `host:add` leave the checked-in configuration unchanged when resolution, installation, or validation fails.

Docker Desktop can leave completion symlinks that predate mise's cask ownership record. During `user:apply`, Maison handles only that exact conflict: a symlink is removed only when it resolves to Docker.app's known completion source, after which package convergence is retried once. Unrelated files and unrelated cask failures remain errors.

## Reproducibility boundary

Nix inputs are pinned by `flake.lock`. Mise lockfiles preserve resolved user and contributor tool versions where metadata exists, but user configuration intentionally retains `latest` declarations and permits network resolution for missing entries. This is repeatable workstation convergence, not strict offline or byte-for-byte reproduction.

Review the [architecture](docs/architecture.md), [deployment guide](docs/deployment.md), [migration contract](docs/migration-contract.md), and [recovery guide](docs/recovery.md) before deleting old generations or backups.

## Development workflow

Maison uses the dstack documentation-first, Beads-backed workflow for planned work.
Use `/plan-features`, `/start-feature <slug>`, `/implement-feature <slug>`,
and `/close-feature <slug>` to keep designs, tasks, validation, and delivery
records aligned.
