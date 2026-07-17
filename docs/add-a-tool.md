# Add a tool or package

## Choose one owner

Use this decision order:

1. **Mise** for a standalone user-scoped developer tool with a trusted release backend and no system/module integration.
2. **nixpkgs** for activation dependencies, services, module-owned programs, reproducible closure contents, and well-supported packages.
3. **Homebrew** for a macOS-specific formula or a bottled binary that avoids a material Nix build cost.
4. **Custom Nix package** only when the preceding sources are unsuitable and the rationale is documented.

Inspect source options without choosing one automatically:

```bash
maison package search <name>
```

## Add a mise tool

```bash
maison tool add <tool> --version latest
```

This updates `[tools]` in `mise.toml`, validates ownership, sorts the table, and shows a diff.

## Add a Nix package

```bash
# Adds to base by default.
maison package add <nixpkgs-attribute>

# Select a narrower profile when appropriate.
maison package add <nixpkgs-attribute> --profile dev
```

The default profile is `base`. Valid profiles are `base`, `dev`, `mac`, and `linux`. Dotted attributes such as `python312Packages.example` are supported. Applicable hosts are evaluated when Nix is available.

Unknown paths fail with the package, profile, system, invalid attribute path, and the `package:search` command.

## Remove software

```bash
maison tool:remove <tool>
maison package:remove <package> --profile <profile>
```

## Ownership conflicts

A package may have one owner. A deliberate temporary overlap must be added to `[[ownership.exceptions]]` in `packages.toml` with the exact owner set and a non-empty reason. `maison check:packages` rejects undocumented duplicates and unused exceptions.

Module-coupled packages stay in the module and are recorded under `[module_owned]` for auditing; do not duplicate their declaration in a profile merely to make it visible.

## GitHub API authentication

Maison, mise, and Nix may query GitHub while resolving tools, flake inputs, and
package metadata. Configure authentication with:

```bash
maison github auth
```

The command offers two local authentication methods:

- A GitHub App with device flow enabled. Maison prompts for the App's public
  client ID and stores it in the user's mise settings; it is not committed to
  the Maison repository.
- GitHub CLI authentication through `gh auth login`.

When Maison detects a GitHub API rate-limit failure, it reports this command
instead of leaving the user with only the underlying `403 Forbidden` response.
