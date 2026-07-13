# Add a macOS application

## Homebrew casks

Use casks for ordinary macOS GUI applications:

```bash
mise run app:add <cask>
```

The command adds the cask to `profiles.mac.homebrew.casks` in `packages.toml`, sorts the list, validates package ownership, and shows the diff.

Remove one with:

```bash
mise run app:remove <cask>
```

## Homebrew formulae

Formulae are explicit data in `packages.toml`:

```toml
[profiles.mac.homebrew]
brews = [
  "owner/tap/formula",
]
```

Use a formula only for macOS-specific software or when the Homebrew bottle is intentionally preferred over a costly/unreliable Nix build. Record cross-source duplication as an ownership exception.

## Mac App Store applications

MAS entries map a display name to the numeric App Store ID:

```toml
[profiles.mac.mas]
"Application Name" = 123456789
```

MAS is for Mac App Store applications only. IDs must be unique integers.

## Platform-specific casks

Put architecture-specific casks under the system table:

```toml
[profiles.mac.homebrew.systems]
aarch64-darwin = ["application"]
```

## Validate and preview

```bash
mise run package:validate
mise run plan
```

Homebrew activation does not auto-update, auto-upgrade, or prune applications. The configuration installs declared items without silently removing unrelated software.
