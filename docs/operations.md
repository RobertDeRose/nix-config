# Operations

## Preview

```bash
maison system plan
maison user plan
maison plan
```

`system:plan` builds without activation. `user:plan` uses mise dry-run/status behavior and does not invoke sudo.

## Apply

```bash
maison system apply
maison user apply
maison apply
```

Use `--host` for an inventory host and `--force-dotfiles` only after reviewing conflicts.

## Inspect drift

```bash
maison doctor
maison user status
maison system history
```

## Update

```bash
maison user update           # frequent tool/package updates
maison update                # flake update + full validation + user update
maison update nixpkgs        # update one flake input
```

`maison update` saves the previous `flake.lock` and restores it when validation fails. It does not activate the updated system automatically.

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
