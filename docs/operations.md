# Operations

## Preview

```bash
maison system plan
maison user plan
maison plan
```

`user:plan` runs first and uses `--force-dotfiles` only with mise dry-run so ownership conflicts are visible without changing files. `system:plan` then builds without activation. Neither preview invokes sudo.

## Apply

```bash
maison system apply
maison user apply
maison apply
```

Use `--host` for an inventory host. Use `--force-dotfiles` only after reviewing `user:plan`; forced apply copies every refused target to a timestamped directory under `~/.local/state/maison/backups/dotfiles` before replacement.

## Inspect drift

```bash
maison doctor
maison user status
maison system history
```

## Update

```bash
maison update                # update flake.lock only
maison update nixpkgs        # update one flake input
maison update --check        # update flake.lock, then run full validation
maison user update           # upgrade mise-managed tools
maison package update        # upgrade Homebrew formulae
maison app update            # upgrade casks and Mac App Store apps
```

Each update surface is an independent transaction. `maison update` changes only `flake.lock` and restores it when the Nix update or optional validation fails. Tool, formula, and application upgrades are explicit so a package-manager or cask failure cannot invalidate a successful Nix lock update. The update commands do not activate the system automatically.

## Clean

```bash
maison system clean 7d
```

This removes old system generations from the platform's canonical system profile, then runs Nix store garbage collection. User tool caches are maintained separately by mise and package managers.

## Add software

```bash
maison package search helix
maison tool add github:owner/tool latest
maison package add brew:tool --macos
maison app add ghostty
```

Package mutation commands change configuration; they do not silently assign ownership to Nix.
