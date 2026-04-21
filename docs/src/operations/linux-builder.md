# Linux Builder

The macOS hosts in this repo use an Apple Container based `aarch64-linux`
builder for Linux derivations. Nix delegates builds to `ssh-ng://container-builder`.

## Current Design

- Declarative entry point: `services.container-builder`
- Host alias: `container-builder`
- Current transport: localhost bridge for the root `nix-daemon`, plus `ProxyCommand` via `~/.local/state/nac/proxy.sh` for user-side helper access
- Durable state directory: `/Users/<username>/.local/state/nac`
- Runtime model: user launch agents start the container runtime and the host-side bridge
- Status helper: `nac`

This is functional, but Apple `container` remains an external mutable runtime,
so this should still be treated as an in-progress integration rather than a
fully hardened subsystem.

## Components

| Component | Location |
|-----------|----------|
| Module | `github:RobertDeRose/nix-apple-container-builder` |
| Host config | `hosts/<arch>-darwin/<hostname>/default.nix` |
| SSH alias | `container-builder` |
| Durable state | `/Users/<username>/.local/state/nac` |
| Root SSH config | `/etc/ssh/ssh_config.d/201-container-builder.conf` |
| Launch agent | `container-builder-runtime` |
| Launch agent | `container-builder-bridge` |

## Host Configuration

Enable the builder per-host in `default.nix`:

```nix
services.container-builder = {
  enable = true;
  cpus = 4;
  memory = "8G";
  maxJobs = 4;
  bridge.enable = true;
};
```

## What Activation Sets Up

Activation installs helper files into the builder state directory:

- `bootstrap-keys.sh`
- `init.sh`
- `proxy.sh`
- `start-container.sh`
- `stop-container.sh`
- `ssh-wrapper.sh`
- `ssh_config`
- `ssh_config_root`
- `cache/` for the persistent NAR metadata cache

It also installs the root SSH alias and configures `nix.buildMachines` so the
daemon can delegate Linux builds to `container-builder`.

The user SSH config uses `ProxyCommand ~/.local/state/nac/proxy.sh`. That proxy
starts the Apple container system if needed, starts the builder on demand,
waits for in-container `sshd`, resolves the current container IP, and then
relays SSH directly to the guest.

The root daemon path still uses the localhost bridge on `127.0.0.1:2222`, which
remains the compatible path for `nix.buildMachines` and real remote builds on
the current host setup.

The builder container itself remains ephemeral, but `/nix` is now mounted as an
overlay filesystem inside the guest. The image's built-in `/nix` stays as the
lower layer while the stable Apple container volume `nix-builder-store` backs
the upper layer so store writes can survive container recreation.

By default the module now expects a custom GHCR builder image with mount tooling
preinstalled for the `/nix` overlay setup.

The module also preserves NAR metadata under
`~/.local/state/nac/cache` and mounts it into the container at
`/var/cache/nix/narinfo`.

## Runtime Behavior

Two user launch agents are installed:

- `container-builder-runtime`
  - bootstraps SSH keys if missing
  - runs `container system start`
  - starts or resumes the builder container
  - removes stale older builder generations automatically
  - waits for a real SSH handshake before considering the builder ready
  - attempts one recovery pass and exits cleanly if the Apple runtime is unhealthy

- `container-builder-bridge`
  - exposes `127.0.0.1:2222`
  - forwards connections into the builder wake-and-relay proxy

## Logs

Logs live in the durable state directory:

- `container-runtime.log`
- `container-runtime.out.log`
- `container-runtime.err.log`
- `container-readiness.log`
- `socat-bridge.out.log`
- `socat-bridge.err.log`

The bridge logs are part of the normal runtime path for daemon-driven builds.

## Verification

Useful checks after activation:

```bash
nac status
nac repair
ssh container-builder true
nix store ping --store ssh-ng://container-builder
nix build --max-jobs 0 --rebuild nixpkgs#legacyPackages.aarch64-linux.hello
```

`nac repair` is the recovery-aware path. It can try to
restart the Apple container runtime before re-checking builder health.

## Known Gaps

- depends on a working Apple `container` installation and user session
- bridge-free daemon access is still not the default path
- the default builder image now depends on the published GHCR package being available
- on-demand startup now works, but the helper and runtime still depend on Apple `container` staying healthy
