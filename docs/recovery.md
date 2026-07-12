# Recovery

## Broken task metadata or executable modes

Validate discovery:

```bash
mise tasks validate
```

Every file under `.mise/tasks/` must be executable, start with `#!/usr/bin/env bash`, and contain a `[MISE] description`. Repair a mode with:

```bash
chmod +x .mise/tasks/<task>
git update-index --chmod=+x .mise/tasks/<task>
```

When mise cannot discover tasks, argument-free tasks can be invoked directly, for example `bash .mise/tasks/doctor`. For a selected host, set the parsed usage variable explicitly: `usage_host=<host> bash .mise/tasks/plan`.

## Invalid inventory

```bash
bash .mise/tasks/host/validate
```

Correct the named object, field, and value in `inventory.toml`. Do not add a fallback identity. If a new host addition failed validation, `host:add` restores the prior inventory automatically.

## Nix daemon failure

Check:

```bash
mise run doctor
```

On macOS, inspect and restart the `org.nixos.nix-daemon` launch daemon. On systemd Linux, inspect `nix-daemon.socket` and `nix-daemon.service`. Then source `/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh` and verify `nix --version`.

## Failed build

`apply` completes all builds before activation. A build failure leaves the active configuration unchanged. Re-run with:

```bash
mise run apply --debug --no-activate
```

Fix the concise prevalidation error first. Use the raw Nix trace only after the host, platform, inventory, and ownership checks pass.

## Failed activation

Run `mise run doctor`, then inspect the build links under `.build/`. A successful build can be retried without rebuilding by invoking the platform activation executable, but prefer `mise run apply` so validation remains consistent.

Rollback:

```bash
mise run rollback
```

On Darwin this selects the previous nix-darwin generation. system-manager does not provide exact nix-darwin generation parity; rollback deactivates the current system-manager generation and does not automatically roll back Home Manager.

## Home Manager conflict

Darwin conflicts are backed up under `~/.hm_bkup/` preserving their relative path. Linux activation uses the `hm_bak` extension. Review the backup and managed target before deleting either copy. Do not add automatic deletion to activation.

## Broken shell

Open a recovery shell using a known system path such as `/bin/bash` or `/bin/zsh`. Inspect the native fragments in `dotfiles/zsh/` and the Home Manager shell module. Build with `mise run apply --no-activate` before reactivating.

## Cache outage

The personal cache is optional. `doctor` reports it as a warning, not a correctness error. Standard caches and local builds remain available. To disable the opt-in for a host:

```toml
[hosts.<hostname>.features]
personal_cache = false
```

Run `mise run plan` afterward. A cache outage may make a custom package slow to build but must not make evaluation depend on the cache.

## Bootstrap failure before mise

The root `bootstrap.sh` owns only prerequisites, clone/checkout selection, mise installation, trust, and handoff. Verify Git, curl, the selected `--repo` and `--ref`, and `$HOME/.local/bin` on `PATH`. Re-run the same command; completed prerequisite steps are idempotent.

## Bootstrap failure after mise

Run from the clone:

```bash
mise run doctor
mise run bootstrap --host <hostname> --no-activate
```

Provide `--system`, `--user`, `--profiles`, `--fullname`, `--email`, and `--github` when a missing host must be created noninteractively. CI/noninteractive execution never prompts for missing identity data.

## Remote deployment failure

`deploy` builds all local outputs before remote modification. Verify SSH connectivity, the inventory hostname, the remote architecture, sudo availability, Nix daemon trust, `/etc/sudoers.d` inclusion, and `sshd_config.d` inclusion. Re-run after correcting the preflight; the task refreshes authorized keys without deleting the last known-good key file when GitHub is unavailable.

## Lockfile update failure

`update` changes only `flake.lock`, prints its diff, and validates all hosts. Restore it with:

```bash
git restore -- flake.lock
```

No activation occurs automatically.
