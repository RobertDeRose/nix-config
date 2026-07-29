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

A Docker Desktop completion ownership error is repaired only when the conflicting path is a symlink to its exact known Docker.app completion file. Unrelated paths are not removed. If the retry fails before Docker replaces a removed link, Maison restores that original link and returns the retry failure.

## Failed remote user deployment

Maison writes `<repo_path>.deploy-state` and retains the prior source as `<repo_path>.previous` until user convergence succeeds. When `user:apply` fails, the deployment command automatically removes the failed source tree and restores the previous repository.

If transaction cleanup itself fails, inspect those two paths before making changes. Do not delete `.previous` while `.deploy-state` exists.

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
