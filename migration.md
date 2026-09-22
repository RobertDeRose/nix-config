# Lix → Upstream Nix Migration

## Scope

This migration converts the current macOS/nix-darwin installation from Lix to
upstream Nix (CppNix). Repository installer and deployment paths are updated to
use upstream Nix on Linux as well, but no existing Linux host is manually
transitioned by this procedure.

## Current state before migration

- Host: `aarch64-darwin` (`USMBDEROSER`)
- Active client: Lix 2.95.2
- Active daemon: `/nix/store/...-lix-2.95.2/bin/nix-daemon`
- Installer receipt: `/nix/receipt.json` from the Lix installer
- nix-darwin manages the active system and `/etc/nix/nix.conf`
- The repository already pins upstream `pkgs.nix` (currently Nix 2.34.8)

## Safety rules

1. Do not run `mise run nix:uninstall` or either installer’s `uninstall` command
   for this conversion. On macOS, full uninstallation can delete the APFS Nix
   Store and all generations.
2. Preserve the existing working tree. At the beginning of this migration the
   unrelated files `mise.lock` and `modules/darwin/apps.nix` were already
   modified; do not overwrite or revert them.
3. Back up the Nix store database before changing the daemon. The backup
   created for this migration is:

   ```text
   /Users/DeRoseR/nix-store-db-20260921-143056.dump
   ```

   The command used was:

   ```bash
   STAMP="$(date +%Y%m%d-%H%M%S)"
   sudo nix-store --dump-db > "$HOME/nix-store-db-$STAMP.dump"
   ```

4. Keep the old nix-darwin generation and do not garbage-collect until the new
   implementation has been exercised successfully. Upstream Nix warns that
   implementation/version changes can affect the store database schema.
5. Do not manually replace `/run/current-system/sw/bin/nix`, `/etc/nix/nix.conf`,
   or the launchd plist. nix-darwin must generate those paths.

## Repository change

`modules/darwin/config.nix` must select upstream Nix on every Darwin host:

```nix
nix.package = pkgs.nix;
```

Remove the Darwin architecture conditional and make the upstream-only
`download-buffer-size` setting unconditional. The Lix-specific selection and
comments must disappear.

Every branch of `mise.toml:install-nix` must use the official installer:

```text
https://artifacts.nixos.org/nix-installer
```

The remote Linux deployment bootstrap and Apple Container test bootstrap must
use the same URL. Update README and architecture/bootstrap documentation to
state that all future hosts use upstream Nix. No existing Linux machine needs
to be manually transitioned.

## Validation and activation

From the repository root, after the source change:

```bash
nix build --accept-flake-config --no-link \
  ".#darwinConfigurations.$(hostname -s).system"

mise run nix:switch
# equivalent:
# sudo darwin-rebuild switch --flake ".#$(hostname -s)"
```

Verify the result:

```bash
/run/current-system/sw/bin/nix --version
nix store ping --store daemon
sudo launchctl print system/org.nixos.nix-daemon | grep -E 'nix-daemon|lix'
```

The generated daemon command should point to an upstream `nix-<version>` store
path, not a `lix-<version>` path. The installer’s old default profile and old
Lix generations may remain as rollback artifacts; that is acceptable and safer
than deleting them during the migration.

For this migration, verification showed:

- `/run/current-system/sw/bin/nix`: `nix (Nix) 2.34.8`
- `nix store ping --store daemon`: trusted daemon, version 2.34.8
- launchd daemon: `/nix/store/gw9jcj6fgf47wvcdh57ga859wv429i7h-nix-2.34.8/bin/nix-daemon`
- active system profile: `system-326-link`
- the old root default profile still contains Lix 2.95.1 and `nss-cacert`; it
  was intentionally left untouched for rollback safety

If activation must be reverted before validation completes:

```bash
sudo darwin-rebuild switch --rollback
```

## Reference documentation

- nix-darwin manages the implementation through `nix.package`:
  <https://github.com/nix-darwin/nix-darwin>
- nix-darwin option reference:
  <https://nix-darwin.github.io/nix-darwin/manual/>
- Official Nix installer:
  <https://github.com/NixOS/nix-installer>
- Nix uninstall warning/details:
  <https://nix.dev/manual/nix/2.35/installation/uninstall.html>
- Nix upgrade/database warning:
  <https://nix.dev/manual/nix/2.35/installation/upgrading.html>

## Migration status

- [x] Investigation completed
- [x] Store database backup completed (`/Users/DeRoseR/nix-store-db-20260921-143056.dump`)
- [x] Repository source/docs updated, including Linux installer paths
- [x] Clean system build completed
- [x] nix-darwin activation completed
- [x] Runtime verification completed
- [x] Normal flake evaluation/build checks completed (including `system-manager`)
- [x] Home-manager activation completed as part of the switch
- [x] Documentation built successfully with `nix shell nixpkgs#mdbook --command mdbook build`
- [x] Old generations retained pending validation
- [x] No Linux host transition performed (not required)

`mise run docs:build` itself could not use the preinstalled mdBook binary because
that binary is for the wrong CPU architecture; the Nix-provided mdBook build
passed instead.
