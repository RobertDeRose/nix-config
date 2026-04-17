# Apple Container Linux Builder for Nix — PoC

## Status: Working (with workaround), investigating simplification

An `aarch64-linux` nix remote builder running in an Apple Container on
macOS, using the `nixos/nix` OCI image. The nix daemon (root) delegates
builds to the container via `ssh-ng://`.

**Current transport**: socat TCP bridge (workaround for XPC + port publishing issues)
**Target transport**: direct port publishing (`-p 127.0.0.1:2222:22`) — pending container system fix

## Architecture

### Current (working, with socat bridge)

```
nix-daemon (root)
  → SSH to "container-builder" host alias
    → localhost:2222
      → socat (user-space, runs as login user)
        → container exec -i nix-builder
          → bash /dev/tcp/127.0.0.1/22 → sshd
            → nix-daemon (container) → builds aarch64-linux
```

**Why the socat bridge?** Two reasons:
1. **XPC is user-scoped**: The `container` CLI talks to the container
   runtime via XPC, which only works for the user who ran
   `container system start`. The nix daemon runs as root and can't
   access the user's XPC services. `container exec` fails from root
   with "XPC connection error: Connection invalid".
2. **Port publishing is broken**: See investigation below. If port
   publishing worked, we could use `-p 127.0.0.1:2222:22` and
   eliminate the socat bridge entirely — root could SSH directly to
   localhost:2222.

### Target (simplified, if port publishing works)

```
nix-daemon (root)
  → SSH to localhost:2222
    → container port publish (-p 127.0.0.1:2222:22)
      → sshd (container port 22)
        → nix-daemon (container) → builds aarch64-linux
```

No socat, no proxy script, no `container exec`. Just standard SSH
to a published port. This is the goal after fixing the container
system.

## Prerequisites

- macOS 26+ (Apple Silicon)
- `container` CLI installed via homebrew (`brew install container`)
- Container system running: `container system start`
- For socat bridge (current workaround): `socat` available (installed via nix)

## Setup (from scratch)

### 1. Create working directory and SSH keys

```bash
mkdir -p /tmp/container-builder
cd /tmp/container-builder

# Generate SSH keypair for the builder user
ssh-keygen -t ed25519 -f builder_ed25519 -N "" -C "container-builder"

# Generate SSH host key for sshd inside the container
ssh-keygen -t ed25519 -f ssh_host_ed25519_key -N "" -C "container-host"
```

### 2. Create the container init script

Write `/tmp/container-builder/init.sh`:

```bash
#!/bin/sh
set -e
export PATH="/root/.nix-profile/bin:$PATH"

# Create builder user
if ! id builder >/dev/null 2>&1; then
  echo "builder:x:1000:1000:builder:/home/builder:/bin/sh" >> /etc/passwd
  echo "builder:x:1000:" >> /etc/group
  mkdir -p /home/builder
  chown 1000:1000 /home/builder
fi

# Configure nix to trust the builder user
mkdir -p /etc/nix
cat > /etc/nix/nix.conf <<'EOF'
trusted-users = root builder
experimental-features = nix-command flakes
build-users-group =
EOF

# Set up SSH authorized keys
mkdir -p /home/builder/.ssh
cp /config/builder_ed25519.pub /home/builder/.ssh/authorized_keys
chmod 700 /home/builder/.ssh
chmod 600 /home/builder/.ssh/authorized_keys
chown -R 1000:1000 /home/builder/.ssh

# Give builder access to nix binaries
mkdir -p /home/builder/.nix-profile/bin
ln -sf /root/.nix-profile/bin/* /home/builder/.nix-profile/bin/ 2>/dev/null || true

# Set up host key
mkdir -p /etc/ssh
cp /config/ssh_host_ed25519_key /etc/ssh/
chmod 600 /etc/ssh/ssh_host_ed25519_key

# Create sshd privsep user
if ! id sshd >/dev/null 2>&1; then
  echo "sshd:x:74:74:sshd privsep:/var/empty:/bin/false" >> /etc/passwd
  echo "sshd:x:74:" >> /etc/group
  mkdir -p /var/empty
fi

# Configure sshd — listen on ALL interfaces (0.0.0.0) so port publishing works
mkdir -p /run/sshd
cat > /etc/ssh/sshd_config <<'EOF'
ListenAddress 0.0.0.0:22
HostKey /etc/ssh/ssh_host_ed25519_key
PermitRootLogin no
PubkeyAuthentication yes
PasswordAuthentication no
ChallengeResponseAuthentication no
UsePAM no
PrintMotd no
AcceptEnv LANG LC_*
SetEnv PATH=/root/.nix-profile/bin:/nix/var/nix/profiles/default/bin:/usr/bin:/bin:/usr/sbin:/sbin
Subsystem sftp /root/.nix-profile/libexec/sftp-server
MaxStartups 64:30:128
MaxSessions 64
EOF

# Start nix-daemon in background
nix-daemon &

# Start sshd as main process (foreground)
exec $(which sshd) -D -e
```

**Important**: sshd must listen on `0.0.0.0` (all interfaces), not
`127.0.0.1`. Port publishing forwards traffic to the container's
network interface IP (192.168.64.x), not loopback.

### 3. Start the container

**Option A: With port publishing (preferred, if working)**

```bash
container run -d \
  --name nix-builder \
  --cpus 4 \
  -m 1G \
  -v /tmp/container-builder/:/config \
  -p 127.0.0.1:2222:22 \
  docker.io/nixos/nix:latest \
  sh -c "sh /config/init.sh"
```

Test:
```bash
sleep 5
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  -i /tmp/container-builder/builder_ed25519 \
  -p 2222 builder@127.0.0.1 echo "port publishing works"
```

If this works, skip to step 5 (SSH config) — no socat or proxy needed.

**Option B: With socat bridge (workaround)**

```bash
container run -d \
  --name nix-builder \
  --cpus 4 \
  -m 1G \
  -v /tmp/container-builder/:/config \
  docker.io/nixos/nix:latest \
  sh -c "sh /config/init.sh"
```

### 4. Set up socat bridge (only if port publishing doesn't work)

Create `/tmp/container-builder/proxy.sh`:

```bash
#!/bin/bash
# Bidirectional TCP forwarding via container exec.
# Spawns bash inside the container that bridges stdin/stdout to sshd.
exec /opt/homebrew/bin/container exec -i nix-builder \
  bash -c 'exec 3<>/dev/tcp/127.0.0.1/22; cat <&3 & cat >&3; kill %1 2>/dev/null'
```

```bash
chmod +x /tmp/container-builder/proxy.sh
```

Start the bridge:

```bash
nohup socat TCP-LISTEN:2222,bind=127.0.0.1,reuseaddr,fork \
  EXEC:/tmp/container-builder/proxy.sh \
  > /tmp/container-builder/socat.log 2>&1 &
echo "socat PID: $!"
```

Also create `/tmp/container-builder/ssh_config` for direct user access
(bypasses socat, useful for testing):

```
Host nix-builder
  User builder
  IdentityFile /tmp/container-builder/builder_ed25519
  ProxyCommand /tmp/container-builder/proxy.sh
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
  LogLevel ERROR
```

### 5. Install system-wide SSH config

```bash
sudo tee /etc/ssh/ssh_config.d/201-container-builder-socat.conf > /dev/null << 'EOF'
Host container-builder
    HostName 127.0.0.1
    Port 2222
    User builder
    IdentityFile /tmp/container-builder/builder_ed25519
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
EOF
```

### 6. Verify root can connect

```bash
sudo ssh -o Port=2222 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  -i /tmp/container-builder/builder_ed25519 builder@127.0.0.1 echo "root works"
```

### 7. Test a nix build

```bash
# Quick test (may use cached result)
sudo nix build --max-jobs 0 -L \
  --builders 'ssh-ng://container-builder aarch64-linux /tmp/container-builder/builder_ed25519 4 1' \
  nixpkgs#legacyPackages.aarch64-linux.hello

# Force rebuild to verify the container actually builds
sudo nix build --max-jobs 0 -L --rebuild \
  --builders 'ssh-ng://container-builder aarch64-linux /tmp/container-builder/builder_ed25519 4 1' \
  nixpkgs#legacyPackages.aarch64-linux.hello
```

The `--builders` format is:
`store-uri system ssh-key max-jobs speed-factor`

The `container-builder` hostname resolves via the SSH config in step 5.

## What works (verified)

- **Full aarch64-linux builds** — compiled GNU hello from source with
  tests (7/7 pass), installed, output copied back to host store
- **Root/nix-daemon access** — via socat TCP bridge (workaround)
- **Sub-second container startup** (Apple Virtualization.framework)
- **`nixos/nix` OCI image** — has sshd built-in, no extra install needed
- **SSH via `container exec -i`** — reliable bidirectional TCP forwarding
  using bash `/dev/tcp` builtin
- **Nix store ping** — `nix store ping --store ssh-ng://...` returns
  `Trusted: 1`, confirming the builder user is trusted
- **`--builders` flag** — nix correctly delegates to the container and
  copies results back via `ssh-ng://`

## Known issues

### Port publishing doesn't forward data

**Status**: Under investigation. Container system was in bad state,
being reinstalled after reboot.

TCP connections to published ports are accepted on the host side but no
data flows in either direction. Tested with:
- `-p 127.0.0.1:2222:22` with sshd on `0.0.0.0:22` — SSH banner never received
- `-p 127.0.0.1:8080:8000` with python http.server on `::` — curl gets no response
- Both used `-d` flag and verified server was running inside container

The `container` process binds the host port (confirmed via `lsof`) but
doesn't relay data to/from the VM. Container system services
(`apiserver`, `vmnet`) were crash-looping with exit code -9.

**After reboot + reinstall**, test:
```bash
container run -d --rm --name port-test \
  -p 127.0.0.1:9090:8000 \
  docker.io/python:alpine \
  python3 -m http.server 8000 --bind '::'
sleep 5
curl http://127.0.0.1:9090/
```

If this works, the socat bridge can be eliminated entirely.

### DNS doesn't work in the container

The container can't resolve `cache.nixos.org` even with `--dns 8.8.8.8`.
This means it can't use binary substitutes — all build dependencies must
be copied from the host store via `ssh-ng://`. This makes builds slower
but doesn't break anything functionally.

### XPC is user-scoped (not fixable)

`container exec` only works for the user who started `container system`.
Root can't use it. This is a macOS security boundary, not a bug. If port
publishing works, this becomes irrelevant (root SSHs directly to the
published port).

### No shared /nix/store (yet)

Bind-mounting the host's `/nix/store` into the container replaces the
container's Linux nix store with Darwin derivations, breaking all Linux
binaries. The stores contain different platform-specific content.

Potential approaches:
- Mount host store at `/host-nix-store`, use `mounted-ssh-ng://` protocol
- Use overlay filesystem (host store as lower, container writes to upper)
- Accept separate stores; `ssh-ng://` `copyPaths()` checks validity
  before copying, so shared paths are skipped

### `containermanagerd` is unrelated

`com.apple.containermanagerd` is Apple's sandboxing service, NOT related
to the `container` CLI. Don't touch it when debugging container issues.

## Files

All PoC files live in `/tmp/container-builder/` (lost on reboot —
regenerate from these instructions).

| File | Purpose |
|------|---------|
| `init.sh` | Container init: creates builder user, configures nix + sshd, starts daemons |
| `proxy.sh` | ProxyCommand: bridges stdin/stdout to container sshd via `container exec -i` |
| `builder_ed25519[.pub]` | SSH keypair for builder user authentication |
| `ssh_host_ed25519_key[.pub]` | SSH host key for container sshd |
| `ssh_config` | SSH config for direct user access (uses ProxyCommand) |

System file:
| File | Purpose |
|------|---------|
| `/etc/ssh/ssh_config.d/201-container-builder-socat.conf` | SSH config for `container-builder` host alias (used by nix daemon) |

## Key technical details

### `nixos/nix` Docker image

- Has nix 2.34.5, openssh (sshd + sftp-server), nix-daemon
- PATH: `/root/.nix-profile/bin:/nix/var/nix/profiles/default/bin`
- Non-interactive SSH sessions need `SetEnv` in sshd_config to set PATH
- `build-users-group =` (empty) in nix.conf is required because the
  image has no `nixbld` group — this makes nix build as the calling user

### nix `--builders` format

```
store-uri system ssh-key max-jobs speed-factor [supported-features] [mandatory-features] [public-host-key]
```

- `store-uri`: `ssh-ng://container-builder` (uses SSH config for host resolution)
- `system`: `aarch64-linux`
- `ssh-key`: path to private key
- Column 7+ is base64-encoded public host key (use `-` to skip)

### `mounted-ssh-ng://` (future optimization)

Nix has a `MountedSSHStore` that assumes remote and local share a
filesystem. Build commands go over SSH, but NARs/logs are read from the
local filesystem — zero network transfer. Gated behind
`mounted-ssh-store` experimental feature. Could be used if we solve
the store sharing problem.

## Comparison with virby

| | Virby (current) | Apple Container (PoC) |
|-|-----------------|----------------------|
| **Startup** | ~9 seconds | <1 second |
| **Backend** | vfkit | Virtualization.framework |
| **Protocol** | `ssh-ng://` | `ssh-ng://` (same) |
| **Daemon access** | Direct SSH (virby manages port) | socat bridge or port publishing |
| **Binary cache** | Works (VM has network) | Broken (DNS issue) |
| **Store sharing** | None | None (yet; VirtioFS possible) |
| **Rosetta/x86_64** | Not supported | Possible (`--rosetta` flag) |
| **Maturity** | Stable, nix-darwin module | PoC, manual setup |
| **macOS** | 13+ | 26+ |

## Next steps

1. **Fix port publishing** — reboot, reinstall `container`, test with
   python http.server example. If it works, eliminate socat bridge.
2. **Fix DNS** — biggest perf win; enables binary cache inside container,
   avoids copying all deps from host
3. **Rosetta** — add `--rosetta` flag for x86_64-linux builds
4. **Store sharing** — VirtioFS + `mounted-ssh-ng://` to eliminate copy overhead
5. **Launchd user agent** — persist socat bridge (if still needed) or
   container auto-start across reboots
6. **nix-darwin module** — declarative config like virby's `services.virby`
7. **On-demand lifecycle** — start/stop container based on build activity
