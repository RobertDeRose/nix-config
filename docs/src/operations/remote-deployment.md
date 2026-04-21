# Remote Deployment

Linux hosts can be configured remotely from a macOS machine using the
`nix:deploy` task.

## How It Works

The deploy task:

1. Builds the system-manager and home-manager configurations **locally** (or on
   the configured Linux builder if cross-compiling)
2. Copies the built closures to the remote host via SSH
3. Activates system-manager and home-manager on the remote host

## Usage

```bash
mise deploy <hostname> [user@host]
```

If the SSH destination is omitted, it defaults to `<hostname>` (assuming SSH
config has the host defined).

## Prerequisites

- The remote host must have Nix installed
- SSH access with key-based authentication
- The local machine must be able to build `aarch64-linux` or `x86_64-linux`
  derivations (via the configured Linux builder or another remote builder)

## SSH Key Setup

This repo uses the [Bitwarden SSH agent](https://bitwarden.com/help/ssh-agent/)
on macOS for key management. The SSH agent configuration is in
`home/darwin/ssh.nix` and uses the Bitwarden desktop app's sandboxed socket.

For remote hosts, SSH authorized keys are fetched from GitHub
(`github.com/<username>.keys`) with a caching mechanism configured in
`modules/linux/system.nix`.
