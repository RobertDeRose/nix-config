# Apple Container testing

On supported macOS hosts:

```bash
maison test:bootstrap
maison test:deploy
```

`test:bootstrap` exercises the pushed branch through the real root bootstrap
boundary in a disposable Linux container. `test:deploy` creates a deterministic,
clean staged repository with a validated test inventory, prepares an SSH target,
and runs the canonical `deploy` task. It does not run `host:add`, because that
would evaluate the same Nix host again immediately before `deploy` builds it.

The deploy test reuses its named container and installed bootstrap prerequisites
across successful runs. It builds the Linux image only when the container is
absent and starts an existing stopped container without rebuilding it. A reused
container still receives the current deployment so the integration boundary is
actually tested. Interrupting either test stops and deletes its container. Local
uncommitted or unpushed changes are not included in the bootstrap URL test.

The test tasks launch systemd explicitly as PID 1 with the capabilities and
`/run` and `/tmp` tmpfs mounts required by Apple Container. The image sets
`container=oci`, but defaults to Bash so running the image without those runtime
options does not attempt an invalid systemd boot.

The tasks wait for the container to accept `container exec` calls before
beginning validation. If PID 1 exits during startup, the task prints
`container inspect` output and container logs before failing.
