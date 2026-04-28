# CI Pipeline

Four GitHub Actions workflows validate and maintain this repository.

## Validate (`ci.yml`)

Reusable workflow (supports `workflow_call`). Runs on pushes to `main` and
pull requests. PR-triggered jobs are skipped for the
`automation/refresh-flake-lock` branch.

### Jobs

**Validate** (ubuntu-latest + macos-latest):

| Step | macOS | Linux |
|------|-------|-------|
| Install Nix | Yes | Yes |
| Evaluate flake metadata | Yes | Yes |
| Evaluate Darwin configs | Yes | -- |
| Evaluate Linux system configs | -- | Yes |
| Evaluate Linux HM configs | -- | Yes |
| Build Darwin configs | Yes | -- |
| Build Linux system configs | -- | Yes |
| Build Linux HM configs | -- | Yes |

**Bootstrap test** (ubuntu-latest + macos-latest):
- Runs `./bootstrap.sh ci-bootstrap` on a fresh runner
- Verifies the bootstrap pipeline reaches the handoff to the real tasks

### What It Catches

- Nix evaluation errors (syntax, missing options, type mismatches)
- Bootstrap script regressions

> **Note**: CI evaluates *and* builds configurations. Build failures are
> caught as part of the validate job.

## Lint (`hk.yml`)

Reusable workflow (supports `workflow_call`). Runs on pull requests (opened,
synchronized, reopened) and manual dispatch. PR-triggered jobs are skipped
for the `automation/refresh-flake-lock` branch.

- Installs Nix and mise (which installs hk and all linting tools)
- Runs `hk check -a` for all configured checks
- Catches formatting, security, and hygiene issues

## Docs (`docs.yml`)

Runs on pushes to `main` and manual dispatch. Only triggers when files under
`docs/`, `.github/workflows/docs.yml`, or `mise.toml` change (path filters).

- Builds the mdBook documentation site
- Deploys to GitHub Pages

## Cache Refresh (`cache-refresh.yml`)

Runs daily on a cron schedule and on manual dispatch.

1. Updates `flake.lock` via `nix flake update`
2. Builds all platform targets (macOS, Intel Mac, ARM Linux, x86 Linux)
   and pushes derivations to `robertderose.cachix.org`
3. If the lockfile changed, commits it to the
   `automation/refresh-flake-lock` branch and opens (or updates) a PR
4. Calls the Validate and Lint reusable workflows against the PR branch
5. Auto-merges the PR with `--admin --squash` after both pass

See [Git Hooks](./git-hooks.md) for the local equivalent of the lint checks.
