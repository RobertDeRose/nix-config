# Task Reference

All tasks are defined in `mise.toml` and run via `mise <task>` or `mise run <task>`.

## Bootstrap & Host Management

| Task | Description |
|------|-------------|
| `nix:init` | Full bootstrap pipeline (install nix, add host, activate) |
| `add-host` | Create a new host directory from template |
| `install-nix` | Install Nix via nix-installer (hidden) |
| `github-auth` | Authenticate with GitHub CLI (hidden) |
| `activate` | Build and activate the current machine's config (hidden) |

## Day-to-Day

| Task | Description |
|------|-------------|
| `nix:switch` (alias: `switch`) | Apply config on the current machine |
| `nix:debug` (alias: `debug`) | Apply config with `--show-trace` for debugging |
| `nix:deploy` (alias: `deploy`) | Build locally and deploy to a remote Linux host |

## Maintenance

| Task | Description |
|------|-------------|
| `nix:up` (alias: `up`) | Update all flake inputs |
| `nix:upp` (alias: `upp`) | Update a single flake input |
| `nix:history` (alias: `history`) | Show flake input metadata |
| `nix:repl` (alias: `repl`) | Open nix repl with flake loaded |
| `nix:clean` (alias: `clean`) | Delete generations older than 7 days |
| `nix:gc` (alias: `gc`) | Aggressive garbage collection |
| `nix:gcroot` (alias: `gcroot`) | List GC roots |
| `nix:fmt` (alias: `fmt`) | Format all .nix files with nixfmt |
| `nix:trust` | Add current user to Nix trusted-users |
| `nix:uninstall` | Fully uninstall Nix from the system |

## iTerm2

| Task | Description |
|------|-------------|
| `iterm:export` | Re-export iTerm2 preferences plist |

## Lima VMs (macOS only)

| Task | Description |
|------|-------------|
| `vm:create` | Create an Ubuntu Lima VM |
| `vm:remove` | Remove the Lima VM |
| `vm:recreate` | Destroy and recreate the VM |
| `vm:shell` | Open a shell in the VM |

## Documentation

| Task | Description |
|------|-------------|
| `docs:build` | Build the mdBook documentation site |
| `docs:serve` | Serve docs locally with hot-reload |
