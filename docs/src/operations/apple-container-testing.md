# Apple Container Testing

[Apple Container](https://developer.apple.com/documentation/containerization)
provides a way to test Linux configurations from macOS before deploying to
real servers.

## Tasks

```bash
# Run the Linux bootstrap flow in a clean Apple container
mise run test:bootstrap
```

## How It Works

The bootstrap test recreates a systemd-capable Ubuntu Apple container,
configures a disposable `tester` account, and runs the pushed branch through
the real bootstrap entrypoint:

```bash
curl -sSfL https://raw.githubusercontent.com/<owner>/<repo>/<branch>/bootstrap.sh | bash -s -- <test-hostname>
```

Uncommitted changes and local commits that have not been pushed to `origin` are
warned about and are not exercised by `test:bootstrap`.

## When to Use

- Testing changes to `modules/linux/system.nix` before deploying to production
- Verifying the bootstrap script works on a clean Ubuntu installation
