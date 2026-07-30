# Remote deployment

Linux deployment is intentionally split into a deploy-rs system transaction and a Maison repository/user transaction.

## System only

```bash
maison system deploy example-linux
maison system deploy example-linux --dry-activate
```

This invokes deploy-rs against `deploy.nodes.example-linux.profiles.system`. The closure is placed in `/nix/var/nix/profiles/system-manager-profiles/system-manager` and activated as root. Schema, activation-path, and dry-activation checks are built in CI.

## System and user

```bash
maison deploy example-linux
```

Before system deployment starts, Maison requires a clean working tree and builds a source archive from committed Git content only. The archive contains `.maison-revision` but never `.git`, dirty changes, untracked files, ignored files, or local credentials.

After successful system activation, Maison:

1. Uploads the archive separately from the remote command stream.
2. Validates that `repo_path` is a normalized descendant of the managed user's home.
3. Allocates a root-owned transaction root on the same filesystem outside any managed-user-writable ancestor.
4. Creates an unpredictable transaction ID, acquires the repository transaction lock, and journals each privileged step.
5. Stages the new source tree and rollback source under the root-owned transaction root.
6. Records expected old/new revisions before finalize.
7. Runs `user:apply` as the managed user from the staged repository.
8. Performs startup recovery of any incomplete repository transaction before proceeding.
9. Finalizes or rolls back by reading the root-owned journal and refusing unsafe ownership, symlink, permission, or cross-filesystem state.

For the default `/home/<user>/.maison` repository path, the default transaction namespace is a root-owned sibling under `/home`, such as `/home/.maison-deploy/transactions/<user>/<repo-hash>/`. Maison fails closed when no same-filesystem root-owned transaction root exists outside the managed user's control.

Remote system and repository actions now run through a separate deployment SSH account (default `maison-deploy`). Sudo access for that account is command-scoped and argument-bounded for `deploy`-related activation and Maison transaction helpers.

Existing hosts that do not yet have a reachable `maison-deploy` account need one bootstrap deployment through an explicitly configured privileged account, such as `ssh_user = "root"`. After that system deployment creates the deployment account and sudoers policy, switch the inventory back to the `maison-deploy` default.

Use `--system-only` to skip repository transfer and user convergence.

## Inventory fields

```toml
[hosts.example-linux.deploy]
enable = true
hostname = "example-linux.example.invalid"
ssh_user = "maison-deploy"
user_ssh_user = "operator"
repo_path = "/home/operator/.maison"
remote_build = false
auto_rollback = true
magic_rollback = true
```

`ssh_user` activates the system with deployment privileges. `user_ssh_user` must equal the managed inventory username. `repo_path` must be below `/home/<user>`; `/`, `/home`, the user's home itself, non-normalized paths, and traversal are rejected by both Python and Nix validation.

## Safety boundary

Deploy-rs rollback covers the system profile. Repository rollback covers the source tree used for the subsequent user convergence. Repository transaction state is privileged state: the managed user must not be able to unlink, replace, or edit journals, staging trees, rollback trees, or locks. Mise changes that completed before a later user-step failure are convergent state, not a Nix generation, and are repaired by rerunning `maison user apply` from the restored repository.
