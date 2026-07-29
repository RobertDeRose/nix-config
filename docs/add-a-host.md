# Add a host

```bash
maison host add <hostname> --system aarch64-linux --user rderose --profiles base,dev,linux --overrides
```

For a deployable Linux host, add an explicit deployment table to `inventory.toml`:

```toml
[hosts.example.deploy]
enable = true
hostname = "example.example.com"
ssh_user = "root"
user_ssh_user = "rderose"
repo_path = "/home/rderose/.maison"
remote_build = false
auto_rollback = true
magic_rollback = true
```

Then run:

```bash
maison host validate
maison system plan --host example
maison system deploy example --dry-activate
```

Host override files may contain OS-level exceptions only. User differences belong in Tera dotfiles or platform mise configuration.
