# Remote deployment

```bash
maison deploy <user@host-or-ssh-alias> [inventory-host]
```

When the inventory host is omitted, the task reads the remote short hostname. It validates that the selected inventory entry is Linux, builds system-manager, the system configuration, and Home Manager before remote changes, installs Lix only when missing, establishes daemon trust, activates system-manager, copies the Home Manager closure, and activates it as the managed user.

Prerequisites are SSH access and root/sudo capability on the remote machine. SSH authorized keys are refreshed from the inventory user's GitHub account by `nix/modules/linux/system.nix`, retaining the last successful file when GitHub is temporarily unavailable.
