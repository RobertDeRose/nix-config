# Linux Builder

This repo uses [`nix-hex-box`](https://github.com/RobertDeRose/nix-hex-box) to
provide the `aarch64-linux` builder used by the Darwin hosts for Linux
derivations.

The integration here is intentionally high-level. The implementation details,
runtime model, recovery flow, generated helper files, and operational guidance
all live in the `nix-hex-box` project documentation.

Project docs:

- <https://robertderose.github.io/nix-hex-box/>

## How This Repo Uses It

The Darwin hosts import the `nix-hex-box` module and enable
`services.container-builder` in host-specific configuration.

Typical settings used in this repo:

```nix
services.container-builder = {
  enable = true;
  cpus = 4;
  memory = "8G";
  maxJobs = 4;
  bridge.enable = true;
};
```

At a high level, this gives the host:

- an Apple Container based `aarch64-linux` builder
- a `container-builder` SSH endpoint used by `nix.buildMachines`
- helper state and logs under `~/.local/state/hb`
- on-demand builder startup for user access
- a compatible bridge path for the root `nix-daemon`

For runtime details, verification steps, recovery behavior, and option
reference, use the upstream project docs instead of this repo chapter.
