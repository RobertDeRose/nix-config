# Remote deployment

```bash
maison deploy <user@host-or-ssh-alias> [inventory-host]
```

Remote deployment assumes the target has already been bootstrapped. It verifies that Homebrew for Linux, mise, and Nix/Lix are present before making changes. If any prerequisite is missing, deployment stops and instructs the operator to run bootstrap first.

When the inventory host is omitted, the task reads the remote short hostname. It validates that the selected inventory entry is Linux, builds system-manager, the system configuration, and Home Manager before remote changes, establishes daemon trust, activates system-manager, copies and activates the Home Manager closure, installs the Maison repository, and installs both global and Maison project mise tools.

Prerequisites are SSH access, root/sudo capability, and a completed Maison bootstrap on the remote machine. SSH authorized keys are refreshed from the inventory user's GitHub account by `nix/modules/linux/system.nix`, retaining the last successful file when GitHub is temporarily unavailable.
