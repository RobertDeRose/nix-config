# Linux Builder VM

The linux builder provides an `aarch64-linux` build environment on macOS,
needed to build Linux derivations locally (e.g., for remote deployment or
cross-platform testing).

We use **[virby](https://github.com/quinneden/virby-nix-darwin)**, which runs
a lightweight NixOS VM via [vfkit](https://github.com/crc-org/vfkit) (Apple
Virtualization.framework). It boots in ~9 seconds and has built-in on-demand
activation with a configurable idle timeout.

## On-Demand Operation

The builder is configured for **on-demand start** — it doesn't run at boot.
When Nix needs to build a Linux derivation, virby automatically boots the VM.
After 30 minutes with no active builds, the VM shuts itself down.

### Components

| Component | Location |
|-----------|----------|
| VM config | `hosts/<arch>-darwin/<hostname>/default.nix` |
| SSH host alias | `virby-vm` |
| Launchd service | `system/org.nix.virby` |
| VM disk | `/var/lib/virby/` |
| Debug log | `/tmp/virbyd.log` (when `debug = true`) |

### VM Resources

- **4 cores**, **8 GiB RAM**
- On-demand with **30-minute idle TTL**

## Manual Control

```bash
# Start the VM
sudo launchctl kickstart system/org.nix.virby

# Stop the VM
sudo launchctl kill SIGTERM system/org.nix.virby

# SSH into the VM (requires allowUserSsh = true, or use sudo)
sudo ssh virby-vm

# Test a build
nix build --rebuild --impure --expr '(with import <nixpkgs> { system = "aarch64-linux"; }; hello)' --max-jobs 0
```

> **Note**: `--max-jobs 0` forces delegation to the remote builder. Without it,
> Nix may download pre-built packages from the binary cache instead of building
> on the VM. `--rebuild` forces a build even if the output already exists.

## Configuration

The builder is enabled per-host. Add this to your host's `default.nix`:

```nix
services.virby = {
  enable = true;
  cores = 4;
  memory = "8GiB";
  onDemand = {
    enable = true;
    ttl = 30; # minutes of idle before shutdown
  };
};
```

### Available Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | `false` | Enable the virby service |
| `cores` | int | `8` | CPU cores for the VM |
| `memory` | int/string | `6144` | RAM (MiB or string like `"8GiB"`) |
| `diskSize` | string | `"100GiB"` | VM disk size |
| `port` | int | `31222` | SSH port |
| `onDemand.enable` | bool | `false` | Start/stop VM automatically |
| `onDemand.ttl` | int | `180` | Idle timeout in minutes |
| `rosetta` | bool | `false` | Enable Rosetta for x86_64-linux builds |
| `debug` | bool | `false` | Verbose logging to `/tmp/virbyd.log` |
| `allowUserSsh` | bool | `false` | Allow non-root SSH access |

See the USMBDEROSER host for a complete example.

## First-Time Setup

Virby requires a two-phase activation on first install:

1. **Add the virby cachix** to `nix.settings` and `nixConfig` in `flake.nix`
2. **Rebuild with `enable = false`** (or pass `--option` flags) so the cache
   is configured and the VM image is downloaded
3. **Set `enable = true`** and rebuild again

This is because the VM image is a Linux derivation — without the binary cache,
Nix would try to build it locally, which requires an existing Linux builder
(chicken-and-egg problem).

> **Important**: Do NOT add `inputs.nixpkgs.follows = "nixpkgs"` to the virby
> input until after the first activation. The cached image hash must match the
> one in the virby binary cache.

## Troubleshooting

```bash
# Enable debug logging
# Set services.virby.debug = true; and rebuild

# View daemon logs
tail -f /tmp/virbyd.log

# Check if the service is registered
sudo launchctl print system/org.nix.virby | grep state

# Check if VM process is running
ps aux | grep vfkit
```
