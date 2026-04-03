# nix-config

Rob's reproducible system configuration using [Nix flakes](https://nixos.wiki/wiki/Flakes),
[nix-darwin](https://github.com/LnL7/nix-darwin), [NixOS](https://nixos.org/), and
[home-manager](https://github.com/nix-community/home-manager).

Built on [flake-parts](https://flake.parts) with [easy-hosts](https://github.com/tgirlcloud/easy-hosts) for auto-discovered host management.

Works on **macOS (Apple Silicon & Intel)** and **NixOS Linux**.

Tasks are managed with [mise](https://mise.jdx.dev). The bootstrap script installs mise, then hands off to it for everything else.

---

## Bootstrapping a New Machine

### macOS

```bash
git clone https://github.com/RobertDeRose/nix-config
cd nix-config
./bootstrap.sh <hostname>
```

`bootstrap.sh` installs mise, then runs `mise run nix:init <hostname>` which:
1. Creates `hosts/aarch64-darwin/<hostname>/` from the darwin template
2. Installs Homebrew (if missing)
3. Installs Nix (if missing)
4. Builds and activates the Darwin configuration

### NixOS / Linux

```bash
git clone https://github.com/RobertDeRose/nix-config
cd nix-config
./bootstrap.sh <hostname>
```

`bootstrap.sh` installs mise, then runs `mise run nix:init <hostname>` which:
1. Creates `hosts/x86_64-nixos/<hostname>/` from the nixos template
2. Auto-copies or generates `hardware-configuration.nix` into the host directory
3. Installs Nix (if missing)
4. Builds and activates the NixOS configuration

---

## Repository Structure

```
.
├── flake.nix                  # Entry point — flake-parts + easy-hosts
├── mise.toml                  # Task runner (nix:init, nix:switch, etc.)
├── bootstrap.sh               # Installs mise → runs nix:init
│
├── hosts/                     # Auto-discovered by easy-hosts
│   ├── aarch64-darwin/        # macOS Apple Silicon hosts
│   │   └── <hostname>/
│   │       └── default.nix
│   ├── x86_64-darwin/         # macOS Intel hosts
│   │   └── <hostname>/
│   │       └── default.nix
│   └── x86_64-nixos/          # NixOS x86_64 hosts
│       └── <hostname>/
│           └── default.nix
│
├── templates/                 # Host templates (copied by nix:add-host)
│   ├── darwin/
│   │   └── default.nix
│   └── nixos/
│       └── default.nix
│
├── modules/
│   ├── common/
│   │   ├── nix-core.nix       # Shared Nix daemon settings (both platforms)
│   │   └── fonts.nix          # Shared font configuration
│   ├── darwin/
│   │   ├── system.nix         # macOS system settings (Dock, Finder, trackpad…)
│   │   └── apps.nix           # Homebrew casks + system-wide nix packages
│   └── nixos/
│       └── system.nix         # NixOS system settings (boot, networking, SSH…)
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
mise run nix:switch

# Debug a failing build
mise run nix:debug

# Update all flake inputs
mise run nix:up

# Update a single input
mise run nix:upp nixpkgs

# Garbage-collect old generations
mise run nix:gc
mise run nix:clean

# Format all .nix files
mise run nix:fmt
```

---

## Adding a New Host

Adding a host requires **no flake.nix editing** — easy-hosts auto-discovers hosts from the `hosts/` directory structure.

### Quick way (from any machine with mise)

```bash
mise run nix:add-host <hostname> [system]
```

This creates `hosts/<arch>-<class>/<hostname>/` from the appropriate template. The `system` argument is optional and defaults to the current machine's platform.

### Manual way

1. Copy a template directory:
   ```bash
   # macOS Apple Silicon
   mkdir -p hosts/aarch64-darwin/<hostname>
   cp templates/darwin/* hosts/aarch64-darwin/<hostname>/

   # NixOS x86_64
   mkdir -p hosts/x86_64-nixos/<hostname>
   cp templates/nixos/* hosts/x86_64-nixos/<hostname>/
   ```
2. For NixOS: copy `hardware-configuration.nix` into the host directory
3. `git add -A && git commit`
4. Run `./bootstrap.sh <hostname>` on the target machine

---

## Notes

- **`flake.lock` is committed** — this pins all inputs for reproducible builds. Run `mise run nix:up` to update.
- **Homebrew** is macOS-only. The `nix:init` task installs it automatically on a fresh machine.
- **Linux packages** are managed entirely through NixOS + home-manager (no Homebrew).
- Cross-platform CLI tools live in `home/common/core.nix` — available on both platforms.
- macOS-specific shell aliases and PATH entries in `home/common/shell.nix` are guarded with `pkgs.stdenv.isDarwin`.

---

## Learning Resources

- [NixOS & Flakes Book](https://github.com/ryan4yin/nixos-and-flakes-book)
- [flake-parts](https://flake.parts)
- [easy-hosts](https://flake.parts/options/easy-hosts.html)
- [nix-darwin options](https://daiderd.com/nix-darwin/manual/index.html)
- [home-manager options](https://nix-community.github.io/home-manager/options.html)
- [NixOS options](https://search.nixos.org/options)
- [nixos-hardware](https://github.com/NixOS/nixos-hardware)
- [mise tasks docs](https://mise.jdx.dev/tasks/)
