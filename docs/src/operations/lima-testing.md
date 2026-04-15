# Lima VM Testing

[Lima](https://lima-vm.io) VMs provide a way to test Linux configurations
from macOS before deploying to real servers.

## Tasks

```bash
# Create a new Ubuntu VM
mise vm:create

# Open a shell in the VM
mise vm:shell

# Recreate the VM (destroy + create)
mise vm:recreate

# Remove the VM
mise vm:remove
```

## How It Works

The `vm:create` task spins up an Ubuntu Lima VM matching the target
architecture. Once inside the VM via `mise vm:shell`, you can test the full
Linux bootstrap and configuration flow:

```bash
# Inside the Lima VM
./bootstrap.sh <test-hostname>
```

This exercises the complete Linux path: Nix installation, system-manager
activation, and home-manager activation.

## When to Use

- Testing changes to `modules/linux/system.nix` before deploying to production
- Verifying the bootstrap script works on a clean Ubuntu installation
- Debugging Linux-specific home-manager issues from macOS
