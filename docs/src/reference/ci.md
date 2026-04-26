# CI Pipeline

Two GitHub Actions workflows validate changes.

## Validate (`ci.yml`)

Runs on pushes to `main` and pull requests.

### Jobs

**Build matrix** (ubuntu-latest + macos-latest):

| Step | macOS | Linux |
|------|-------|-------|
| Install Nix | Yes | Yes |
| Flake check | Yes | Yes |
| Build Darwin configs | Yes | -- |
| Build Linux system configs | -- | Yes |
| Build Linux HM configs | -- | Yes |

**Bootstrap test** (separate job):
- Runs `./bootstrap.sh ci-bootstrap` on a fresh runner
- Verifies the bootstrap pipeline reaches the handoff to the real tasks
- Evaluates the target configurations without building or activating them (CI mode)

### What It Catches

- Nix evaluation errors (syntax, missing options, type mismatches)
- Build failures in any host configuration
- Bootstrap script regressions

## Lint (`hk.yml`)

Runs on pull requests (opened, synchronized, reopened) and manual dispatch.

- Installs mise (which installs hk and all linting tools)
- Runs `hk check -a` for all configured checks
- Catches formatting, security, and hygiene issues

## Docs (`docs.yml`)

Runs on pushes to `main` and manual dispatch.

- Builds the mdBook documentation site
- Deploys to GitHub Pages

See [Git Hooks](./git-hooks.md) for the local equivalent of the lint checks.
