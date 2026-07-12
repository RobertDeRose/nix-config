# Apple Container testing

On supported macOS hosts:

```bash
mise run test:bootstrap
mise run test:deploy
```

`test:bootstrap` exercises the pushed branch through the real root bootstrap boundary in a disposable Linux container. `test:deploy` creates a staged inventory host with `host:add`, installs Nix in a disposable SSH target, and runs the canonical `deploy` task. Local uncommitted or unpushed changes are not included in the bootstrap URL test.
