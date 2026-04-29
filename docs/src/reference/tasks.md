# Task Reference

All tasks are defined in `mise.toml` and are safest to run as
`mise run <task>`.

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
| `nix:switch` | Apply config on the current machine |
| `nix:debug` | Apply config with `--show-trace` for debugging |
| `nix:dry-run` | Dry-run a build target or the current host config |
| `nix:check-cache` | Check whether a store path exists in configured substituters |
| `nix:deploy` | Build locally and deploy system config to a remote Linux host |

## Maintenance

| Task | Description |
|------|-------------|
| `nix:up` | Update a single flake input, or all inputs if none specified |
| `nix:history` | List system profile generations via `nix-env` |
| `nix:repl` | Open a nix repl with nixpkgs |
| `nix:clean` | Remove system generations older than a retention window |
| `nix:gc` | Garbage-collect unused store entries across the machine |
| `nix:gcroot` | List auto GC roots |
| `nix:fmt` | Format all `.nix` files with the configured formatter |
| `nix:trust` | Add current user to Nix trusted-users |
| `nix:uninstall` | Fully uninstall Nix from the system |

## iTerm2

| Task | Description |
|------|-------------|
| `iterm:export` | Re-export iTerm2 preferences plist |

## Apple Container Tests (macOS only)

| Task | Description |
|------|-------------|
| `test:image` | Build the Apple Container Linux test image (hidden) |
| `test:bootstrap` | Run Linux bootstrap validation in an Apple container |
| `test:deploy` | Run Apple Container remote deployment validation |

## Documentation

| Task | Description |
|------|-------------|
| `docs:build` | Build the mdBook documentation site |
| `docs:serve` | Serve docs locally with hot-reload |

Hidden helper tasks also exist for bootstrap flow: `install-nix`,
`github-auth`, `add-host`, and `activate`.
