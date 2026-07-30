# Add a host

```bash
maison host add <hostname> --system aarch64-linux --user rderose --profiles base,dev,linux --overrides
```

For a deployable Linux host, add an explicit deployment table to `inventory.toml`:

```toml
[hosts.example.deploy]
enable = true
hostname = "example.example.com"
ssh_user = "maison-deploy"
user_ssh_user = "rderose"
repo_path = "/home/rderose/.maison"
remote_build = false
auto_rollback = true
magic_rollback = true
```

`ssh_user` is the deployment account used for system activation and repository-transaction helper access. It defaults to `maison-deploy` and is separate from the managed user (`user_ssh_user`), which owns the remote repository. For a first deployment to an existing host that does not yet have a reachable `maison-deploy` account, temporarily set `ssh_user` to an existing privileged account for the system deployment, then switch back to `maison-deploy` after the account and sudoers policy exist.

Then run:

```bash
maison host validate
maison system plan --host example
maison system deploy example --dry-activate
```

Host override files may contain OS-level exceptions only. User differences belong in Tera dotfiles or platform mise configuration.
