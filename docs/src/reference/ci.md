# CI pipeline

## Validate

`.github/workflows/ci.yml` has three contracts:

1. `repository-checks` installs Nix and mise tools, then runs `mise run check`.
2. `build-configurations` runs on x86_64 Linux, ARM64 Linux, and macOS, builds exported packages for the runner system, and builds inventory hosts whose system matches that runner.
3. `bootstrap-steps` exercises root `bootstrap.sh` on Linux and macOS with a disposable inventory host.

The shared build script reads `inventory.toml`; it does not scan directories or generate synthetic host layouts.

## Lint

`.github/workflows/hk.yml` runs `hk check -a`, including Nix/TOML/shell formatting, actionlint, ShellCheck, mise validation, and repository hygiene checks.

## Documentation

`.github/workflows/docs.yml` builds the mdBook site and deploys it to GitHub Pages.

## Cache refresh

`.github/workflows/cache-refresh.yml` updates `flake.lock`, builds each runner system's package and inventory targets, uploads cache results, opens or updates the automation pull request, invokes lint and validation, and merges only after both pass. The personal cache is not required by ordinary host correctness.
