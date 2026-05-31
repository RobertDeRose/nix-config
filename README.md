# nix-config

My reproducible system configuration using [Nix flakes](https://nixos.wiki/wiki/Flakes),
[nix-darwin](https://github.com/LnL7/nix-darwin), [system-manager](https://github.com/numtide/system-manager),
and [home-manager](https://github.com/nix-community/home-manager).

Built on [flake-parts](https://flake.parts) with [easy-hosts](https://github.com/tgirlcloud/easy-hosts)
for macOS host discovery. Non-NixOS Linux hosts are managed separately with `system-manager`.

Works on **macOS (Apple Silicon & Intel)** and **Ubuntu Linux (headless servers)**.
Tasks are managed with [mise](https://mise.jdx.dev). The bootstrap script installs prerequisites,
then delegates to mise for host creation, Nix installation, and activation.

---

## Bootstrapping a New Machine

Run this on a fresh machine — it handles prerequisites, cloning, host scaffolding, Nix installation,
and config activation:

```bash
sh -c 'curl -sSfL https://raw.githubusercontent.com/RobertDeRose/nix-config/main/bootstrap.sh | bash -s -- <hostname>'
```

Or if you've already cloned the repo:

```bash
./bootstrap.sh <hostname>
```

### What it does

**macOS:**

1. Installs Xcode Command Line Tools (if missing)
2. Clones this repo (if not already inside it)
3. Creates `hosts/<arch>-darwin/<hostname>/` from the Darwin template
4. Installs Homebrew (if missing)
5. Installs Nix/Lix (if missing; CppNix is used on Intel macOS)
6. Builds and activates the nix-darwin configuration

**Ubuntu / Linux (headless):**

1. Clones this repo (if not already inside it)
2. Creates `systems/<arch>-linux/<hostname>/` from the Linux template
3. Installs Nix/Lix (if missing)
4. Builds and activates the system-manager configuration
5. Builds and activates the Linux home-manager configuration

---

## Repository Structure

```text
.
├── flake.nix                  # Entry point — flake-parts, easy-hosts, Linux discovery
├── mise.toml                  # Task runner (init, switch, deploy, tests, docs)
├── bootstrap.sh               # One-liner bootstrap entry point
│
├── hosts/                     # Darwin hosts only; auto-discovered by easy-hosts
│   ├── aarch64-darwin/        # macOS Apple Silicon hosts
│   │   └── <hostname>/
│   │       ├── default.nix
│   │       ├── user.nix       # Host user metadata
│   │       └── home.nix       # Optional per-host macOS HM overrides
│   └── x86_64-darwin/         # macOS Intel hosts
│       └── <hostname>/
│           ├── default.nix
│           ├── user.nix
│           └── home.nix
│
├── systems/                   # Non-NixOS Linux hosts; consumed by flake.nix
│   ├── aarch64-linux/
│   │   └── <hostname>/
│   │       ├── system.nix     # Optional per-host system-manager overrides
│   │       ├── user.nix       # Host user metadata
│   │       └── home.nix       # Optional per-host Linux HM overrides
│   └── x86_64-linux/
│       └── <hostname>/
│           ├── system.nix
│           ├── user.nix
│           └── home.nix
│
├── templates/                 # Host templates copied by add-host
│   ├── darwin/
│   │   ├── default.nix
│   │   └── home.nix
│   └── linux/
│       ├── system.nix
│       └── home.nix
│
├── modules/
│   ├── common/
│   │   └── cache.nix          # Shared binary cache endpoints and trusted keys
│   ├── darwin/
│   │   ├── config.nix         # nix-darwin and Home Manager wiring
│   │   ├── system.nix         # macOS system settings (Dock, Finder, trackpad…)
│   │   ├── apps.nix           # Homebrew casks, MAS apps, and system packages
│   │   ├── fonts.nix          # macOS fonts
│   │   ├── homebrew-mas-fix.nix
│   │   └── iterm2.nix
│   └── linux/
│       └── system.nix         # Shared system-manager config (SSH, users, packages…)
│
└── home/
    ├── darwin.nix             # macOS home-manager entry point
    ├── linux.nix              # Linux home-manager entry point
    ├── darwin/                # macOS-specific HM modules
    └── common/
        ├── default.nix        # Imports all shared home modules
        ├── core.nix           # Cross-platform CLI tools
        ├── shell.nix          # zsh, Starship, aliases, PATH, shell integration
        ├── git.nix            # git, gh, lazygit
        ├── direnv.nix         # direnv + nix-direnv + mise
        ├── pi.nix             # Pi coding-agent customization
        ├── omp.nix            # Oh My Posh configuration
        └── *.ts               # Pi UI extension modules
```

---

## Day-to-Day Commands

Use `mise run <task>`; `mise.toml` is the source of truth.

```bash
# List all available tasks
mise tasks

# Apply config on the current machine (auto-detects hostname + platform)
mise run nix:switch

# Debug a failing activation with verbose output and Nix traces
mise run nix:debug

# Dry-run the current host build, or a specific flake target
mise run nix:dry-run
mise run nix:dry-run .#systemConfigs.<host>

# Install and use hk hooks/checks
hk install --mise
hk check -a

# Update all flake inputs, or one input
mise run nix:up
mise run nix:up nixpkgs

# Garbage-collect old generations/store paths
mise run nix:gc
mise run nix:clean

# Format Nix files
mise run nix:fmt

# Build docs
mise run docs:build
```

---

## Adding a New Host

Adding a host requires **no flake.nix editing**. Darwin hosts are auto-discovered from `hosts/` by
easy-hosts. Linux hosts are discovered by the custom flake logic from `systems/*-linux/` so they do
not get interpreted as NixOS hosts by easy-hosts.

### Quick way (from any machine with mise)

```bash
mise run add-host <hostname> [os] [arch] \
  --user <username> \
  --fullname "Full Name" \
  --email user@example.com \
  --github githubUsername
```

`os` accepts `darwin|linux`; `arch` accepts `aarch64|x86_64`. Omitted values default to the current
machine. Missing user metadata is inferred from the current user/git config or prompted for.

### Manual way

1. Copy a template directory:
   ```bash
   # macOS Apple Silicon
   mkdir -p hosts/aarch64-darwin/<hostname>
   cp templates/darwin/* hosts/aarch64-darwin/<hostname>/

   # Ubuntu ARM
   mkdir -p systems/aarch64-linux/<hostname>
   cp templates/linux/* systems/aarch64-linux/<hostname>/
   ```
2. Add `user.nix` in the host directory with `username`, `fullname`, `useremail`, and `githubUsername`.
3. `git add -A && git commit`
4. Run `./bootstrap.sh <hostname>` on the target machine.

---

## Notes

- **`flake.lock` is committed** — this pins all inputs for reproducible builds. Run `mise run nix:up` to update.
- **Homebrew** is macOS-only. The init path installs it automatically on a fresh machine.
- **Linux system config** is managed via [system-manager](https://github.com/numtide/system-manager) — packages, services, users, SSH, sudoers, hostname, locale, and timezone.
- **Linux user config** is managed via home-manager in `home/linux.nix`.
- Darwin host directories live under `hosts/<arch>-darwin/<hostname>/`.
- Linux host directories live under `systems/<arch>-linux/<hostname>/`.
- Optional per-host home-manager overrides can be added as `home.nix` inside a host directory.
- Cross-platform CLI tools live in `home/common/core.nix`.
- Platform-specific shell behavior in `home/common/shell.nix` is guarded with `pkgs.stdenv.isDarwin` or `pkgs.stdenv.isLinux`.

### Git Hooks (hk)

- This repo uses [`hk`](https://hk.jdx.dev/) for pre-commit and pre-push checks.
- `mise.toml` is the source of truth for hk tooling and environment (`HK_MISE=1`).
- Hooks auto-install via mise postinstall (`hk install --mise`).
- You can also install manually once per clone: `hk install --mise`.
- `hk` configuration lives in `hk.pkl` and uses builtins for formatting, shell/yaml/workflow checks, and security checks.

---

## Learning Resources

- [NixOS & Flakes Book](https://github.com/ryan4yin/nixos-and-flakes-book)
- [flake-parts](https://flake.parts)
- [easy-hosts](https://flake.parts/options/easy-hosts.html)
- [nix-darwin options](https://daiderd.com/nix-darwin/manual/index.html)
- [home-manager options](https://nix-community.github.io/home-manager/options.html)
- [system-manager docs](https://system-manager.net/)
- [mise tasks docs](https://mise.jdx.dev/tasks/)
