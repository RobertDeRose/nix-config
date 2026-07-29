# Remote deployment

Linux deployment is intentionally split into a deploy-rs system transaction and a Maison repository/user transaction.

## System only

```bash
maison system deploy dev-som
maison system deploy dev-som --dry-activate
```

This invokes deploy-rs against `deploy.nodes.dev-som.profiles.system`. The closure is placed in `/nix/var/nix/profiles/system-manager-profiles/system-manager` and activated as root. Schema, activation-path, and dry-activation checks are built in CI.

## System and user

```bash
maison deploy dev-som
```

Before system deployment starts, Maison requires a clean working tree and builds a source archive from committed Git content only. The archive contains `.maison-revision` but never `.git`, dirty changes, untracked files, ignored files, or local credentials.

After successful system activation, Maison:

1. Uploads the archive separately from the remote command stream.
2. Validates that `repo_path` is a normalized descendant of the managed user's home.
3. Extracts and verifies it as `<repo>.next.<pid>`.
4. Moves an existing repository to `<repo>.previous` and records `<repo>.deploy-state`.
5. Runs `user:apply` as the managed user.
6. Removes `.previous` only after success, or restores it automatically after failure.

Use `--system-only` to skip repository transfer and user convergence.

## Inventory fields

```toml
[hosts.dev-som.deploy]
enable = true
hostname = "dev-som.example.com"
ssh_user = "root"
user_ssh_user = "rderose"
repo_path = "/home/rderose/.maison"
remote_build = false
auto_rollback = true
magic_rollback = true
```

`ssh_user` activates the system. `user_ssh_user` must equal the managed inventory username. `repo_path` must be below `/home/<user>`; `/`, `/home`, the user's home itself, non-normalized paths, and traversal are rejected by both Python and Nix validation.

## Safety boundary

Deploy-rs rollback covers the system profile. Repository rollback covers the source tree used for the subsequent user convergence. Mise changes that completed before a later user-step failure are convergent state, not a Nix generation, and are repaired by rerunning `maison user apply` from the restored repository.
