# Recovery

## System rollback

```bash
maison system history
maison system rollback
```

On Darwin, the task prefers `darwin-rebuild switch --rollback` and does not move the profile first. On Linux, it rolls back `/nix/var/nix/profiles/system-manager-profiles/system-manager` and activates the selected profile's `bin/activate`.

## Failed aggregate apply

`maison apply` runs system state first. A system failure prevents user convergence. A later user failure leaves the successfully activated system generation in place:

```bash
maison user status
maison user plan
maison user apply
```

## Failed user apply

The dry run previews whole-file ownership changes with force enabled but does not modify files. After review, rerun with `--force-dotfiles`; Maison backs up the exact targets mise refused before replacement.

Targeted migration backups are stored under:

```text
~/.local/state/maison/backups/git
~/.local/state/maison/backups/dotfiles/<timestamp>
~/.local/state/maison/backups/pi
```

Before package convergence on macOS, Maison also sanitizes this backup tree. Any live `.app` bundle is archived
in place as `.app.zip`, unregistered from LaunchServices, and removed only after the archive is non-empty and passes ZIP verification.
Maison also creates `.metadata_never_index` at the backup root. This prevents Mac App Store installers from
relocating future updates into a backup copy instead of `/Applications`. `maison user plan` previews this
migration without modifying the backup.

Restore an archived application bundle only for forensic or recovery purposes:

```bash
ditto -x -k path/to/Application.app.zip /tmp/application-restore
```

Do not leave an extracted `.app` under the Maison backup tree.

A Docker Desktop completion ownership error is repaired only when the conflicting path is a symlink to its exact known Docker.app completion file. Unrelated paths are not removed. If the retry fails before Docker replaces a removed link, Maison restores that original link and returns the retry failure.

## Failed remote user deployment

Maison records repository transaction state in a root-owned same-filesystem transaction root outside the managed user's writable home. For the default `/home/<user>/.maison` repository path, inspect the root-owned namespace under `/home/.maison-deploy/transactions/<user>/`.

When `user:apply` fails, the deployment command rolls back from the root-owned journal and rollback tree. If transaction cleanup itself fails, inspect the journal, staging tree, rollback tree, and lock under the root-owned transaction root before making changes. Do not delete transaction journals or rollback trees until the active repository state is understood.

## Failed system deployment

The user phase does not start until the system phase succeeds. With `auto_rollback` and `magic_rollback` enabled, deploy-rs attempts to restore the prior system profile after activation failure or loss of confirmation connectivity.

## nix-darwin adoption files

The one-time Darwin preflight may preserve unmanaged files as:

```text
/etc/nix/nix.conf.before-nix-darwin
/etc/nix/nix.custom.conf.before-nix-darwin
```

Retain them until several successful switches have completed.

## Broken shell

Use `/bin/zsh` or `/bin/bash`, ensure `~/.local/bin` is on `PATH`, and inspect `~/.zshrc` plus `~/.config/maison/zsh`. The shell is user-owned, so repairing it does not require rebuilding the Nix system closure.
