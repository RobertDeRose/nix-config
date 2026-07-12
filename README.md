# nix-config

Nix-backed system management with a small mise command interface. The repository supports Apple Silicon and Intel macOS through nix-darwin, ARM64 and x86_64 non-NixOS Linux through system-manager, and user configuration through Home Manager.

```bash
mise tasks
mise run doctor
mise run plan
mise run apply
mise run check
mise run update
```

Routine use should not require knowing flake output names or platform-specific activation commands.

## Common changes

| Change | Source of truth | Command |
| --- | --- | --- |
| Standalone developer tool | `mise.toml` `[tools]` | `mise run tool:add <tool>` |
| Nix-managed package | `packages.toml` | `mise run package:add <package> --profile <profile>` |
| macOS GUI application | `packages.toml` Homebrew casks | `mise run app:add <cask>` |
| Git, Helix, Starship, Zsh, Zellij, Pi, or OpenCode settings | `dotfiles/<application>/` | Edit the native file, then `mise run plan` |
| Host, system, user, or profiles | `inventory.toml` | `mise run host:add <hostname> ...` |
| Host-specific exception | `hosts/<hostname>/system.nix` or `home.nix` | Create only when an exception is required |

Package-source selection is documented in [`docs/package-policy.md`](docs/package-policy.md).

## Public machine-management commands

```bash
mise run doctor                         # Read-only machine diagnostics
mise run plan [--host <hostname>]       # Read-only build preview
mise run apply [--host <hostname>]      # Build the complete target, then activate
mise run apply --no-activate            # Build without activation
mise run check                          # Validate tasks, data, Nix, hosts, and tests
mise run update [input]                 # Update the lockfile and validate hosts
mise run rollback [--yes]               # Platform-aware rollback
mise run deploy <destination> [host]    # Remote Linux deployment
```

The former `nix:init`, `nix:switch`, `nix:debug`, `nix:dry-run`, `nix:deploy`, `nix:up`, and `add-host` names remain as hidden compatibility wrappers.

## Fresh-machine bootstrap

The root script performs only work required before mise is available. After installing and trusting mise, it delegates Nix/Lix installation, host validation, building, and activation to `mise run bootstrap`.

```bash
curl -fsSL https://raw.githubusercontent.com/RobertDeRose/nix-config/main/bootstrap.sh \
  | bash -s -- --host my-host --repo RobertDeRose/nix-config --ref main
```

From an existing clone:

```bash
./bootstrap.sh --host my-host
```

Re-running bootstrap is safe. Existing hosts are validated rather than recreated. New hosts are added to `inventory.toml` without creating a branch, staging files, committing, or pushing.

## Adding configuration

```bash
# A standalone developer tool managed by mise
mise run tool:add usage --version latest

# A Nix package in an intent-oriented profile
mise run package:add ripgrep --profile developer

# A macOS Homebrew cask
mise run app:add firefox

# A host
mise run host:add build-server \
  --system x86_64-linux \
  --user rderose \
  --profiles base,developer,linux-server
```

Each mutation command validates the result and displays a Git diff. `host:add` commits only when `--commit` is explicitly supplied.

## Architecture

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

`inventory.toml` declares all users, hosts, systems, profiles, and optional feature flags. `packages.toml` declares ordinary profile and host package ownership. `mise.toml` contains only settings, tool versions, environment, hooks, and file-task discovery.

```text
.
├── flake.nix                 # Inputs and delegation only
├── inventory.toml            # Users, hosts, systems, profiles, features
├── packages.toml             # Package ownership and data-driven lists
├── mise.toml                 # Mise settings/tools; no substantial task bodies
├── bootstrap.sh              # Pre-mise bootstrap boundary
├── .mise/tasks/              # Executable user-facing tasks
├── .mise/lib/                # Shared shell implementation, never exposed as tasks
├── nix/outputs.nix           # Flake output construction
├── nix/lib/                  # Inventory, validation, profiles, constructors
├── nix/profiles/             # base, developer, mac-desktop, linux-server
├── nix/modules/              # Low-level Darwin, Linux, and Home Manager modules
├── nix/checks/               # Inventory, ownership, and host checks
├── hosts/<hostname>/         # Optional host exceptions only
├── dotfiles/                 # Native application configuration
├── tests/tasks/              # Mocked task and library regression tests
└── docs/                     # Architecture, workflows, policy, and recovery
```

The stable flake outputs remain:

- `darwinConfigurations.<host>` for macOS.
- `systemConfigs.<host>` for non-NixOS Linux system state.
- `homeConfigurations.<host>` for Linux Home Manager state.

`flake-parts` is retained only for concise per-system formatter, package, and check wiring. Host discovery and construction no longer depend on it.

## Validation and recovery

`mise run check` is read-only and runs task metadata validation, Bash/Python checks, ShellCheck, shell formatting, Nix formatting and flake checks, TOML/inventory/ownership validation, every host evaluation, and regression tests. CI runs the same contract and builds same-system outputs.

`mise run doctor` reports missing prerequisites, host/platform mismatches, daemon state, optional cache availability, task modes, repository dirtiness, and likely Home Manager link conflicts.

See:

- [`docs/architecture.md`](docs/architecture.md)
- [`docs/task-reference.md`](docs/task-reference.md)
- [`docs/add-a-host.md`](docs/add-a-host.md)
- [`docs/add-a-tool.md`](docs/add-a-tool.md)
- [`docs/add-an-app.md`](docs/add-an-app.md)
- [`docs/recovery.md`](docs/recovery.md)
