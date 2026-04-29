# Bootstrapping

The `bootstrap.sh` script handles everything needed to set up a fresh machine
from zero to a fully configured system.

## One-Liner

```bash
sh -c 'curl -sSfL https://raw.githubusercontent.com/RobertDeRose/nix-config/main/bootstrap.sh | bash -s -- <hostname>'
```

## What It Does

### macOS

1. Installs **Xcode Command Line Tools** (if missing)
2. Clones this repo to `~/workspace/personal/nix-config` (if not already inside it)
3. Creates `hosts/<arch>-darwin/<hostname>/` from the darwin template (if it
   doesn't exist)
4. Installs **Nix** (if missing):
   - **x86_64-darwin** uses the upstream `nix-installer`
   - all other macOS hosts use the **Lix** installer
5. Runs the repo activation flow, which builds and switches the nix-darwin
   configuration
6. Lets `nix-homebrew` manage Homebrew during nix-darwin activation rather than
   treating Homebrew as a separate bootstrap step

### Linux (Ubuntu headless)

1. Clones this repo (if not already inside it)
2. Creates `systems/<arch>-linux/<hostname>/` from the linux template
3. Installs **Lix** (if missing)
4. Builds and activates **system-manager** configuration
5. Builds and activates **home-manager** configuration

## After Bootstrap

Once the initial bootstrap completes, day-to-day changes are applied with:

```bash
mise run nix:switch
```

## CI Mode

The bootstrap script supports a `ci-bootstrap` argument for testing in CI
without actually activating:

```bash
./bootstrap.sh ci-bootstrap
```

This runs the full pipeline but evaluates configurations without building,
verifying the flake is valid on a fresh machine.
