# Architecture

## Design goal

Nix remains the system-management engine. Mise is the stable human-facing command layer. Home Manager remains the owner of user configuration and dotfile deployment. Routine changes are made in explicit TOML inventories or native application files rather than in flake wiring.

## Ownership boundaries

### Nix-family tooling

Nix, Lix, nix-darwin, system-manager, and Home Manager own system state, users, permissions, sudoers, SSH, services, shell integration, activation dependencies, reproducible closures, and Nix development environments.

### Mise

Mise owns command discovery, task help and argument parsing, repository validation tools, suitable standalone developer tools, and dispatch into `.mise/lib/`. Substantial task bodies are executable files under `.mise/tasks/`; helper libraries under `.mise/lib/` are not task-discovery paths.

### Home Manager

Home Manager deploys checked-in native configuration from `dotfiles/`. Static settings are not translated into Nix unless a module option is required. Host/user-dependent values remain small generated fragments.

### Homebrew and MAS

Homebrew owns macOS GUI applications, macOS-specific formulae, and selected bottled binaries. MAS owns Mac App Store IDs. Neither owns Linux software.

## Data flow

```text
inventory.toml
      │
      ▼
host constructor ──► profiles ──► platform modules
      │
      ├────────────► Home Manager
      ├────────────► nix-darwin
      └────────────► system-manager
```

`inventory.toml` is parsed once by `nix/lib/inventory.nix`. Validation produces structured `host` and `user` records. `nix/lib/mk-darwin-host.nix` and `mk-linux-host.nix` select profile module lists and preserve the public output names.

Shell tasks read the same inventory through `.mise/lib/inventory.sh`. `plan`, `apply`, `deploy`, `doctor`, and host commands therefore share host names, systems, users, profile rules, and error behavior with Nix evaluation.

## Inventory

The inventory contains:

- `schema` version.
- Optional defaults.
- Explicit users and identity metadata.
- Explicit hosts and Nix systems.
- Intent-oriented profile lists.
- Optional host feature flags such as the personal cache.

Missing hosts, missing users, unsupported systems, unknown profiles, and platform-incompatible profiles fail before raw Nix traces are shown. There is no silent default identity. The existing uppercase Darwin account is an explicit, Darwin-only compatibility exception; newly created accounts must be portable lowercase names.

Host override files are optional:

```text
hosts/<hostname>/system.nix
hosts/<hostname>/home.nix
```

They contain exceptions only. System, user, and profile metadata are not duplicated there.

## Profiles

The profile registry in `nix/lib/profiles.nix` exposes `darwinModules`, `linuxModules`, and `homeModules` for four profiles:

- `base`: shared shell, Git, basic utilities, and common Home Manager state.
- `developer`: editor and developer integrations.
- `mac-desktop`: nix-darwin, macOS defaults, Homebrew, MAS, fonts, and desktop-specific Home Manager state.
- `linux-server`: system-manager users, sudoers, SSH, services, packages, and Linux Home Manager state.

Profiles express machine purpose. Low-level reusable implementation remains under `nix/modules/`; there is no profile per application.

## Package resolution

`packages.toml` declares ordinary profile and host package lists. `nix/lib/packages.nix` selects entries for the host system, and `nix/lib/resolve-package.nix` resolves dotted nixpkgs attribute paths. Unknown or non-derivation attributes identify the package, profile, system, invalid path, and search command.

Module-coupled packages remain beside the module and are listed under `[module_owned]` for ownership auditing. Temporary duplicate ownership requires an exact owner set and written reason. The Python validator in `.mise/lib/config_edit.py` checks sorting, duplicates, inventory references, and exceptions.

The personal Cachix cache is opt-in per host. All configured caches are acceleration only: substitute failures fall back to local builds, and read-only host evaluation avoids package-specific caches.

## Native dotfiles

Static configuration is authored under:

```text
dotfiles/git/
dotfiles/helix/
dotfiles/starship/
dotfiles/zellij/
dotfiles/zsh/
dotfiles/pi/
dotfiles/opencode/
```

Home Manager links or installs these files. Git identity and other genuinely dynamic values are generated separately. Existing conflicting files are backed up predictably rather than deleted silently.

## Command flow

`apply` and `plan` call the same target constructors in `.mise/lib/nix.sh`.

```text
host selection
   └─► inventory validation
         └─► platform validation
               └─► target resolution
                     ├─► plan: Nix dry run only
                     └─► apply: complete build ─► activation
```

Linux builds include system-manager, the system configuration, and Home Manager before either activation runs. Darwin builds the complete nix-darwin system before `darwin-rebuild switch` runs. A failed build leaves the active machine unchanged.

`deploy` uses the same Linux target constructors and builds all closures before modifying the remote machine. `check`, `doctor`, and `plan` contain no activation or sudo path.

## Flake wiring

`flake.nix` declares inputs and delegates to `nix/outputs.nix`. Filesystem scanning and easy-hosts are removed. `flake-parts` is retained because it still reduces the per-system formatter, package, and check wiring; removing it would add code without simplifying host construction.

The output contract remains:

```text
darwinConfigurations.<host>
systemConfigs.<host>
homeConfigurations.<host>
```
