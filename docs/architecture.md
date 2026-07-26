# Architecture

## Principle

Maison separates configuration by privilege boundary, not by operating system or package ecosystem:

```text
Nix/Lix system layer
├── nix-darwin on macOS
├── system-manager on Linux
├── nh for local Darwin builds/switches
└── deploy-rs for remote Linux deployment

mise user layer
├── tools and runtimes
├── ordinary Homebrew formulae/casks and MAS apps
├── dotfiles and Tera templates
├── current-user macOS defaults
└── user services
```

## Nix system layer

The flake exports `darwinConfigurations`, `systemConfigs`, and `deploy`.

### macOS

nix-darwin owns:

- Nix/Lix daemon configuration and caches.
- Primary-user registration and system shell registration.
- Apple Watch and Touch ID authentication for sudo.
- Login-window policy.
- Caps Lock-to-Escape key remapping.
- Host identity, time zone, and system services.
- System-wide fonts and OS-integrated installers such as FUSE-T.
- Native Homebrew only for those OS-integrated casks.
- `nh`, `deploy-rs`, and `nixd` as administration tools.

Ordinary applications and interactive CLI packages do not belong in `environment.systemPackages`.

### Linux

system-manager owns:

- Hostname, locale, time zone, and managed user.
- Sudoers and SSH daemon includes.
- Root-owned Nix configuration.
- GitHub-backed authorized-key refresh.
- System services, their closure dependencies, and the minimal `curl`/Git/tar bootstrap toolchain needed before mise exists.

`/nix/var/nix/profiles/system-manager-profiles/system-manager` is the canonical Linux system profile.

## nh

Darwin planning and activation use:

```bash
nh darwin build  . -H <host>
nh darwin switch . -H <host>
```

The tasks fall back to `nix run .#nh` before the system profile has installed `nh`.

system-manager has no native `nh system` command in this branch. Linux local application remains a small adapter around the pinned system-manager CLI. This keeps the proposed future `nh` contribution isolated from the migration.

## deploy-rs

Each deploy-enabled Linux inventory host becomes `deploy.nodes.<host>`. The `system` profile:

- Uses the canonical system-manager profile path.
- Runs as root.
- Activates the exact closure selected by deploy-rs through `$PROFILE/bin/activate`.
- Enables `autoRollback` and `magicRollback` from inventory.

The local deploy-rs adapter uses the same `pkgs.deploy-rs` package for the CLI,
remote activation binary, and version-matched schema. Deployment schema and
activation-path checks are exported only for systems that own deploy-enabled
hosts.

## mise user layer

The repository-level `mise.toml` owns dotfile deployment and repository validation tools. It installs a global user configuration under `~/.config/mise/`.

The global user configuration owns:

- Versioned tools in `[tools]`.
- Platform packages in `[bootstrap.packages]`.
- Current-user macOS preferences.
- User environment variables.

Application configuration remains in native formats under `dotfiles/`; Tera is used only when host/user/platform interpolation is required.

## macOS defaults boundary

Mise may write current-user preference domains such as Dock, Finder, trackpad, screenshots, and application preferences.

Mise must not own:

- `sudo defaults` domains.
- `/Library/Preferences` policy.
- Login-window or authentication policy.
- PAM configuration.
- Host-scoped `defaults -currentHost` values.

Those remain in nix-darwin even when an equivalent raw defaults key exists.

## Package platforms

Mise's built-in Homebrew backend is used for ordinary user-facing packages on Apple Silicon macOS and Linux. Those declarations live in `config.macos-arm64.toml` and `config.linux.toml`. System-wide fonts and FUSE-T remain in nix-darwin; FUSE-T uses the minimal Nix-managed native Homebrew exception in `nix/modules/darwin/homebrew-system.nix`.

`config.macos-x64.toml` deliberately does not claim package parity. Adding an Intel host requires choosing native Homebrew, another mise package manager, or explicit platform exceptions before activation.

## Transactions

System and user application are deliberately separate:

```text
maison apply
  1. system:apply  (Nix generation semantics)
  2. user:apply    (mise convergence semantics)
```

A failure in step 2 does not make the system generation invalid. Conversely, deploy-rs system rollback does not revert user dotfiles or upgraded tools.
