# Add a tool or package

## Choose one owner

Use this decision order:

1. **Mise** for a standalone user-scoped developer tool with a trusted release backend and no system/module integration.
2. **nixpkgs** for activation dependencies, services, module-owned programs, reproducible closure contents, and well-supported packages.
3. **Homebrew** for a macOS-specific formula or a bottled binary that avoids a material Nix build cost.
4. **Custom Nix package** only when the preceding sources are unsuitable and the rationale is documented.

Inspect source options without choosing one automatically:

```bash
mise run package:search <name>
```

## Add a mise tool

```bash
mise run tool:add <tool> --version latest
```

This updates `[tools]` in `mise.toml`, validates ownership, sorts the table, and shows a diff.

## Add a Nix package

```bash
mise run package:add <nixpkgs-attribute> --profile developer
```

Valid profiles are `base`, `developer`, `mac-desktop`, and `linux-server`. Dotted attributes such as `python312Packages.example` are supported. Applicable hosts are evaluated when Nix is available.

Unknown paths fail with the package, profile, system, invalid attribute path, and the `package:search` command.

## Remove software

```bash
mise run tool:remove <tool>
mise run package:remove <package> --profile <profile>
```

## Ownership conflicts

A package may have one owner. A deliberate temporary overlap must be added to `[[ownership.exceptions]]` in `packages.toml` with the exact owner set and a non-empty reason. `mise run package:validate` rejects undocumented duplicates and unused exceptions.

Module-coupled packages stay in the module and are recorded under `[module_owned]` for auditing; do not duplicate their declaration in a profile merely to make it visible.
