# Git Hooks

This repo uses [hk](https://hk.jdx.dev/) for pre-commit and lint checks.
Configuration lives in `hk.pkl` (Pkl language).

## Setup

Hooks auto-install via the mise postinstall hook. You can also install manually:

```bash
hk install --mise
```

## Running Checks

```bash
# Run all checks
hk check -a

# Fix auto-fixable issues
hk fix -a
```

## Configured Checks

### Formatting

| Check | Files | What it does |
|-------|-------|-------------|
| `nixfmt` | `**/*.nix` | Format Nix files |
| `shfmt` | `**/*.sh` | Format shell scripts |
| `pkl_format` | `**/*.pkl` | Format Pkl files |
| `tombi_format` | `**/*.toml` | Format TOML files |
| `actionlint` | `.github/workflows/*.yml` | Lint GitHub Actions |
| `shellcheck` | `**/*.sh` | Lint shell scripts |
| `mise-fmt` | `mise.toml` | Format the mise config |
| `mise` | `mise.toml` | Validate mise task definitions |

### Security & Hygiene

| Check | What it does |
|-------|-------------|
| `detect-private-key` | Catch accidentally committed private keys |
| `check-merge-conflict` | Detect merge conflict markers |
| `check-added-large-files` | Prevent large file commits |
| `check-byte-order-marker` | Detect UTF-8 BOM |
| `check-case-conflict` | Detect case-only filename conflicts |
| `check-symlinks` | Validate symlink targets exist |

### Whitespace

| Check | What it does |
|-------|-------------|
| `trailing-whitespace` | Remove trailing whitespace |
| `mixed-line-ending` | Enforce consistent line endings |
| `newlines` | Ensure files end with newline |
