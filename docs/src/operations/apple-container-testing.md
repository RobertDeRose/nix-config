# Apple Container testing

On supported macOS hosts:

```bash
mise run test:bootstrap
mise run test:deploy
```

`test:bootstrap` exercises the pushed branch through the real root bootstrap boundary in a disposable Linux container. `test:deploy` creates a staged inventory host with `host:add`, installs Nix in a disposable SSH target, and runs the canonical `deploy` task. Local uncommitted or unpushed changes are not included in the bootstrap URL test.

The test tasks launch systemd explicitly as PID 1 with the capabilities and
`/run` and `/tmp` tmpfs mounts required by Apple Container. The image sets
`container=oci`, but defaults to Bash so running the image without those runtime
options does not attempt an invalid systemd boot.

The tasks wait for the container to accept `container exec` calls before
beginning validation. If PID 1 exits during startup, the task prints
`container inspect` output and container logs before failing.
