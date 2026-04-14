# nix-config

My reproducible system configuration using [Nix flakes](https://nixos.wiki/wiki/Flakes),
[nix-darwin](https://github.com/LnL7/nix-darwin), [system-manager](https://github.com/numtide/system-manager), and
[home-manager](https://github.com/nix-community/home-manager).

Built on [flake-parts](https://flake.parts) with [easy-hosts](https://github.com/tgirlcloud/easy-hosts) for
auto-discovered host management.

Works on **macOS (Apple Silicon & Intel)** and **Ubuntu Linux (headless servers)**.

Tasks are managed with [mise](https://mise.jdx.dev). The bootstrap script installs mise, then hands off to it for
everything else.

---

## Bootstrapping a New Machine

Run this on a fresh machine — it handles everything (Xcode CLT, git clone, mise, Nix, Homebrew, config build):

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
3. Creates `hosts/aarch64-darwin/<hostname>/` from the darwin template
4. Installs Homebrew (if missing)
5. Installs Nix (if missing)
6. Builds and activates the Darwin configuration

**Ubuntu / Linux (headless):**
1. Clones this repo (if not already inside it)
2. Creates `hosts/x86_64-linux/<hostname>/` from the linux template
3. Installs Nix (if missing)
4. Builds and activates the system-manager configuration
5. Builds and activates the Linux home-manager configuration

---

## Repository Structure

```
.
├── flake.nix                  # Entry point — flake-parts + easy-hosts
├── mise.toml                  # Task runner (init, switch, etc.)
├── bootstrap.sh               # One-liner bootstrap (curl | bash friendly)
│
├── hosts/                     # Auto-discovered by easy-hosts
│   ├── aarch64-darwin/        # macOS Apple Silicon hosts
│   │   └── <hostname>/
│   │       ├── default.nix
│   │       └── home.nix       # Optional per-host macOS HM overrides
│   ├── x86_64-darwin/         # macOS Intel hosts
│   │   └── <hostname>/
│   │       ├── default.nix
│   │       └── home.nix       # Optional per-host macOS HM overrides
│   ├── x86_64-linux/          # Ubuntu x86_64 hosts (headless)
│   │   └── <hostname>/
│   │       ├── system.nix
│   │       └── home.nix       # Optional per-host Linux HM overrides
│   └── aarch64-linux/         # Ubuntu ARM hosts (headless)
│       └── <hostname>/
│           ├── system.nix
│           └── home.nix       # Optional per-host Linux HM overrides
│
├── templates/                 # Host templates (copied by add-host)
│   ├── darwin/
│   │   ├── default.nix
│   │   └── home.nix
│   └── linux/
│       ├── system.nix
│       └── home.nix
│
├── modules/
│   ├── common/
│   │   ├── nix-core.nix       # Nix daemon settings used by darwin config
│   │   └── fonts.nix          # Shared font configuration
│   ├── darwin/
│   │   ├── system.nix         # macOS system settings (Dock, Finder, trackpad…)
│   │   └── apps.nix           # Homebrew casks + system-wide nix packages
│   └── linux/
│       └── system.nix         # Shared system-manager config (SSH, users, packages…)
│
└── home/
    ├── darwin.nix             # macOS home-manager entry point
    ├── linux.nix              # Linux home-manager entry point
    └── common/
        ├── default.nix        # Imports all shared home modules
        ├── core.nix           # Cross-platform CLI tools
        ├── shell.nix          # zsh + starship (platform-aware)
        ├── git.nix            # git, gh, lazygit
        └── direnv.nix         # direnv + nix-direnv + mise
```

---

## Day-to-Day Commands

```bash
# List all available tasks
mise tasks

# Apply config on the current machine (auto-detects hostname + platform)
mise switch

# Debug a failing build
mise debug

# Install and use hk hooks
mise hk:install
mise hk:check
mise hk:fix

# Update all flake inputs
mise up

# Update a single input
mise upp nixpkgs

# Garbage-collect old generations
mise gc
mise clean

# Format all .nix files
mise fmt
```

---

## Adding a New Host

Adding a host requires **no flake.nix editing** — easy-hosts auto-discovers macOS hosts from the `hosts/` directory,
and system-manager auto-discovers Linux hosts from `hosts/*-linux/`.

### Quick way (from any machine with mise)

```bash
mise add-host <hostname> [os] [arch]
```

This creates `hosts/<arch>-<class>/<hostname>/` from the appropriate template. `os` accepts `darwin|linux` and `arch`
accepts `aarch64|x86_64`; both default to the current machine when omitted.

### Manual way

1. Copy a template directory:
   ```bash
   # macOS Apple Silicon
   mkdir -p hosts/aarch64-darwin/<hostname>
   cp templates/darwin/* hosts/aarch64-darwin/<hostname>/

   # Ubuntu x86_64
   mkdir -p hosts/x86_64-linux/<hostname>
   cp templates/linux/* hosts/x86_64-linux/<hostname>/
   ```
2. `git add -A && git commit`
3. Run `./bootstrap.sh <hostname>` on the target machine

---

## Notes

- **`flake.lock` is committed** — this pins all inputs for reproducible builds. Run `mise up` to update.
- **Homebrew** is macOS-only. The `init` task installs it automatically on a fresh machine.
- **Linux system config** is managed via [system-manager](https://github.com/numtide/system-manager) — packages, services, users, etc.
- **Linux user config** (dotfiles, shell) is managed via home-manager in `home/linux.nix`.
- Optional per-host macOS home-manager overrides can be added at `hosts/<arch>-darwin/<hostname>/home.nix`.
- Optional per-host Linux home-manager overrides can be added at `hosts/<arch>-linux/<hostname>/home.nix`.
- Cross-platform CLI tools live in `home/common/core.nix` — available on both platforms.
- macOS-specific shell aliases and PATH entries in `home/common/shell.nix` are guarded with `pkgs.stdenv.isDarwin`.

### Git Hooks (hk)

- This repo uses [`hk`](https://hk.jdx.dev/) for pre-commit and pre-push checks.
- `mise.toml` is the source of truth for hk tooling and environment (`HK_MISE=1`).
- Hooks auto-install via mise postinstall (`hk install --mise`).
- You can also install manually once per clone: `mise hk:install`.
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
