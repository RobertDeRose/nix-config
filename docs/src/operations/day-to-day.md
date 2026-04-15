# Day-to-Day Commands

All commands are run via [mise](https://mise.jdx.dev) tasks defined in `mise.toml`.

## Common Commands

```bash
# Apply config on the current machine (auto-detects hostname + platform)
mise switch

# Debug a failing build (show trace)
mise debug

# Update all flake inputs
mise up

# Update a single input
mise upp nixpkgs

# Garbage-collect old generations
mise gc      # aggressive: delete all old generations
mise clean   # gentle: delete generations older than 7 days

# Format all .nix files
mise fmt

# Open a nix repl with the flake loaded
mise repl
```

## Listing All Tasks

```bash
mise tasks
```

This shows every available task grouped by category. Hidden tasks (internal
building blocks) are not shown by default.

## Platform Detection

`mise switch` and `mise debug` automatically detect:

- **Hostname** from the system
- **Platform** (darwin vs linux)
- **Architecture** (aarch64 vs x86_64)

They then run the appropriate build command (`darwin-rebuild switch` on macOS,
`system-manager switch` + `home-manager switch` on Linux).

## Flake History

```bash
# Show recent flake input changes
mise history
```

This runs `nix flake metadata` to display the locked revisions and dates of
all inputs.
