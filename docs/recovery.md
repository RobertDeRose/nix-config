# Recovery

## System rollback

```bash
maison system history
maison system rollback
```

On Darwin, the task prefers `darwin-rebuild switch --rollback`. It does not move the profile first, which would accidentally advance two generations.

On Linux, it runs `nix-env --rollback` on `/nix/var/nix/profiles/system-manager-profiles/system-manager` and activates the selected profile's `bin/activate`.

## Failed user apply

A failed mise bootstrap does not invalidate the Nix system generation.

```bash
maison user status
maison user plan
maison user apply
```

The dry run previews whole-file ownership changes with force enabled but does not modify files. After review, rerun with `--force-dotfiles`; Maison backs up the exact targets mise refused before replacement.

Targeted migration backups are stored under:

```text
~/.local/state/maison/backups/git
~/.local/state/maison/backups/dotfiles/<timestamp>
~/.local/state/maison/backups/pi
```

## Failed remote user deployment

The prior checkout is retained as `<repo_path>.previous`. Restore it over SSH, then run `mise run user:apply` from that checkout.

## Failed system deployment

Do not run the user phase until the system phase is healthy. Inspect deploy-rs output and the canonical system-manager profile. With `auto_rollback` and `magic_rollback` enabled, deploy-rs attempts to restore the prior system profile after activation failure or loss of confirmation connectivity.

## nix-darwin adoption files

The one-time Darwin preflight may preserve unmanaged files as:

```text
/etc/nix/nix.conf.before-nix-darwin
/etc/nix/nix.custom.conf.before-nix-darwin
```

Retain them until several successful system switches have completed.

## Broken shell

Use `/bin/zsh` or `/bin/bash`, ensure `~/.local/bin` is on `PATH`, and inspect `~/.zshrc` plus `~/.config/maison/zsh`. Because the shell is user-owned, repairing it does not require rebuilding the Nix system closure.
