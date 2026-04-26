# Day-to-Day Commands

All commands are run via [mise](https://mise.jdx.dev) tasks defined in `mise.toml`.

## Common Commands

```bash
# Apply config on the current machine (auto-detects hostname + platform)
mise run nix:switch

# Debug a failing build (show trace)
mise run nix:debug

# Update all flake inputs
mise run nix:up

# Update a single input
mise run nix:up nixpkgs

# Garbage-collect old generations
mise run nix:gc      # aggressive: delete old system and user generations
mise run nix:clean   # remove old system generations older than 7 days

# Format all .nix files
mise run nix:fmt

# Open a nix repl with the flake loaded
mise run nix:repl
```

## Listing All Tasks

```bash
mise tasks
```

This shows every available task grouped by category. Hidden tasks (internal
building blocks) are not shown by default.

## Platform Detection

`mise run nix:switch` and `mise run nix:debug` automatically detect:

- **Hostname** from the system
- **Platform** (darwin vs linux)
- **Architecture** (aarch64 vs x86_64)

They then run the appropriate build command (`darwin-rebuild switch` on macOS,
`system-manager switch` + `home-manager switch` on Linux).

## Flake History

```bash
# Show recent flake input changes
mise run nix:history
```

This shows the system profile generation history for the current machine.
