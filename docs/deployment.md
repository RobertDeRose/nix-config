# Remote deployment

Linux deployment is intentionally split into system and user phases.

## System only

```bash
maison system deploy dev-som
maison system deploy dev-som --dry-activate
```

This invokes deploy-rs against `deploy.nodes.dev-som.profiles.system`. A preflight creates system-manager's profile directory when necessary; the Nix closure is then selected locally, transferred by deploy-rs, placed in `/nix/var/nix/profiles/system-manager-profiles/system-manager`, and activated as root.

## System and user

```bash
maison deploy dev-som
```

After a successful system activation, Maison:

1. Archives the repository, including `.git` for location-independent tasks.
2. Uploads it separately from the remote command stream.
3. Stages it as `<repo>.next.<pid>`.
4. Retains the old checkout as `<repo>.previous`.
5. Runs `user:apply` as the managed user.

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

`ssh_user` activates the system. `user_ssh_user` owns and applies the user environment.

## Safety boundary

Deploy-rs rollback covers only the `system` profile. The subsequent mise run is a separate convergence operation and has no claim to atomic rollback with the system generation.
