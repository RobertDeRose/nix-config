# Linux Builder VM

The nix-darwin linux-builder provides an `aarch64-linux` build environment on
macOS via a QEMU virtual machine. This is needed to build Linux derivations
locally (e.g., for remote deployment or cross-platform testing).

## On-Demand Operation

The builder is configured for **on-demand start** -- it doesn't run at boot.
Instead, it starts automatically when Nix needs to build a Linux derivation
and shuts itself down after 30 minutes of idle.

### How It Works

1. **Nix initiates an SSH connection** to the `linux-builder` remote builder
2. **SSH ProxyCommand** detects the VM isn't running and calls
   `launchctl kickstart` to start it
3. **The proxy waits** for SSH on port 31022 to become available (up to 120s)
4. **Connection is handed off** via `nc localhost 31022`
5. **Guest idle timer** checks every 5 minutes for active SSH sessions; if none
   are found after 30 minutes, the VM powers off

### Components

| Component | Location |
|-----------|----------|
| VM config | `hosts/<arch>-darwin/<hostname>/default.nix` |
| SSH config | `/etc/ssh/ssh_config.d/100-linux-builder.conf` |
| ProxyCommand | Nix store script (`linux-builder-proxy`) |
| Launchd plist | `/Library/LaunchDaemons/org.nixos.linux-builder.plist` |
| SSH key | `/etc/nix/builder_ed25519` |
| VM disk | `/var/lib/linux-builder/nixos.qcow2` |

### Guest Configuration

The VM runs NixOS with:

- **4 cores** and **3 GB RAM** (upstream defaults)
- **systemd idle-shutdown timer** -- checks for active `sshd` processes
- **Build features**: `kvm`, `benchmark`, `big-parallel`

## Manual Control

```bash
# Start the VM
sudo launchctl kickstart system/org.nixos.linux-builder

# Stop the VM
sudo launchctl kill SIGTERM system/org.nixos.linux-builder

# Check status
sudo launchctl print system/org.nixos.linux-builder | grep state

# Test a build
nix build nixpkgs#legacyPackages.aarch64-linux.hello --no-link --max-jobs 0
```

> **Note**: `--max-jobs 0` forces delegation to the remote builder. Without it,
> Nix may download pre-built packages from the binary cache instead of building
> on the VM.

## Configuration

The builder is enabled per-host. Add this to your host's `default.nix`:

```nix
nix.linux-builder = {
  enable = true;
  maxJobs = 4;
  config = { pkgs, ... }: {
    virtualisation.cores = 4;
  };
};
```

The on-demand launchd overrides and SSH ProxyCommand are also set in the host
config. See the USMBDEROSER host for a complete example.
