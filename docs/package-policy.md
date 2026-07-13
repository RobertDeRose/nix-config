# Package ownership policy

Every user-visible package has one primary source. Platform-specific ownership is allowed only when the difference is explicit and validated.

## Decision order

1. **Mise** owns standalone, user-scoped developer and repository-validation tools when a maintained prebuilt release is available and no system integration is required.
2. **Nix** owns packages required by nix-darwin, system-manager, Home Manager modules, activation code, services, or reproducible system closures.
3. **Homebrew** owns macOS GUI applications, macOS-specific formulae, and binaries whose upstream bottles avoid costly or unreliable local Nix builds.
4. **MAS** owns Mac App Store applications.
5. **Custom Nix packages** are a last resort and require a documented upstream, supported systems, source-selection rationale, and cache expectations.

Ordinary profile and host package changes belong in `packages.toml`. Mise tools remain in `mise.toml`. Packages selected implicitly by a Home Manager `programs.*` option or required inside activation logic are listed under `[module_owned]` for auditability while their actual declarations stay with the module.

## Current explicit exceptions

`jq` is intentionally present in two closures: mise supplies the interactive/CI command, while the Pi activation script embeds `pkgs.jq` so activation cannot depend on the user environment. `worktrunk` is Homebrew-owned on macOS to avoid an uncached Rust build and Nix-owned on Linux; its Home Manager module remains supplied by the flake input. Both exceptions are encoded with reasons in `packages.toml`.

## Custom Nix package group: llm-agents.nix

The `llmagents` flake input currently supplies `herdr`, `opencode`, `openspec`, and `pi` through `nix/packages/custom/llmagents.nix`.

- Upstream: `numtide/llm-agents.nix`.
- nixpkgs is insufficient because these rapidly changing agent binaries are not all available there at compatible versions.
- Mise is not used because the current input provides one cross-platform, Nix-evaluated package set shared by Home Manager modules.
- Homebrew is not used because the tools must also work on Linux and do not all have equivalent formulae.
- Supported systems are the systems exported by the upstream input; host evaluation fails clearly when a package is absent.
- Cache misses can trigger local builds. The personal cache is acceleration only and is not a correctness requirement.

Reassess this exception when all four tools have suitable, trusted mise backends or nixpkgs packages.

## Adding software

Use `mise run package:search <name>` to inspect available source classes. Then use one explicit command:

```bash
maison tool:add <tool>
maison package:add <package> [--profile <profile>]
maison app:add <cask>
```

The commands show a diff and run ownership validation. They never choose a source silently and never stage, commit, or push.
