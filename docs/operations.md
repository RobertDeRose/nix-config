# Operations

## Fresh setup with a private overlay

Use `--overlay` during bootstrap, or set `MAISON_OVERLAY_SOURCE` from the environment or a mise secret:

```bash
./bootstrap.sh --host "$(hostname -s)" --overlay GIT-URL-OR-PATH
```

Maison stores the selected source in `${XDG_STATE_HOME:-$HOME/.local/state}/maison/overlay.toml` and clones or updates it at `${XDG_DATA_HOME:-$HOME/.local/share}/maison/overlay`. Interactive bootstrap may prompt for the overlay source when it is required; non-interactive bootstrap fails instead of continuing with public starter data for a real machine.

`maison host add` mutates the active inventory repository. With an overlay inventory, new hosts and optional `hosts/<name>/system.nix` stubs are written to the overlay clone, not to public Maison.

## Preview

```bash
maison system plan
maison user plan
maison plan
```

`maison plan` previews the system layer first and then the user layer, matching `maison apply`. `user:plan` uses forced dotfile handling only with mise dry-run so ownership conflicts are visible without changing files.

## Apply

```bash
maison system apply
maison user apply
maison apply
```

`maison apply` activates system state first. The user phase starts only after system success. Repository deployment uses revision-bound finalize checks and startup recovery under the root-owned transaction namespace before user convergence restarts. Use `--host` for an inventory host. Use `--force-dotfiles` only after reviewing `user:plan`; Maison backs up the exact refused targets before replacement.

User package convergence handles one known Docker Desktop cask migration conflict. It removes only six known completion symlinks when each resolves to its exact Docker.app completion source, then retries once. Any regular file, unrelated symlink, or unrelated installer failure remains an error. If the retry fails before Docker replaces a removed link, Maison restores the original link and returns the retry failure.

## Inspect drift

```bash
maison doctor
maison user status
maison system history
```

## Validate and develop

```bash
maison check
mise install
mise exec -- hk check
```

Repository development tools are owned by the checkout `mise.toml`; normal user convergence does not install them from the global user config.

## Update

```bash
maison update                # update flake.lock only
maison update nixpkgs        # update one flake input
maison update --check        # update flake.lock, then run full validation
maison user update           # upgrade mise-managed tools
maison package update        # upgrade Homebrew formulae
maison app update            # upgrade casks and Mac App Store apps
```

Each update surface has an independent failure boundary. `maison update` restores `flake.lock` when the Nix update or optional validation fails. Tool, formula, and application upgrades are explicit and do not activate the system.

## Clean

```bash
maison system clean 7d
```

This removes old system generations from the canonical platform profile, then runs Nix store garbage collection. User tool caches are maintained separately.

## Add software

```bash
maison package search helix
maison tool add github:owner/tool latest
maison package add brew:tool
maison app add ghostty
```

Add operations commit configuration only after successful installation or resolution. Package mutation does not silently assign ownership to Nix.
