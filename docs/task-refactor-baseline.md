# Mise task refactor baseline

All tasks below were originally embedded in `mise.toml`.

| Task | Hidden | Host mutation | Sudo possible | Git mutation | Planned file |
| --- | ---: | ---: | ---: | ---: | --- |
| `install-nix` | yes | yes | yes | no | `.mise/tasks/install-nix` |
| `github-auth` | yes | yes | no | no | `.mise/tasks/github-auth` |
| `add-host` | yes | files | no | yes | `.mise/tasks/add-host` |
| `activate` | yes | yes | yes | no | `.mise/tasks/activate` |
| `nix:init` | no | yes | yes | yes | `.mise/tasks/nix/init` |
| `nix:switch` | no | yes | yes | no | `.mise/tasks/nix/switch` |
| `nix:debug` | no | yes | yes | no | `.mise/tasks/nix/debug` |
| `nix:dry-run` | no | no | no | no | `.mise/tasks/nix/dry-run` |
| `nix:check-cache` | no | no | no | no | `.mise/tasks/nix/check-cache` |
| `nix:deploy` | no | remote | yes | no | `.mise/tasks/nix/deploy` |
| `nix:trust` | no | yes | yes | no | `.mise/tasks/nix/trust` |
| `nix:up` | no | lockfile | no | no | `.mise/tasks/nix/up` |
| `nix:history` | no | no | no | no | `.mise/tasks/nix/history` |
| `nix:repl` | no | no | no | no | `.mise/tasks/nix/repl` |
| `nix:clean` | no | yes | no | no | `.mise/tasks/nix/clean` |
| `nix:gc` | no | yes | yes | no | `.mise/tasks/nix/gc` |
| `nix:fmt` | no | files | no | no | `.mise/tasks/nix/fmt` |
| `iterm:export` | no | files | no | no | `.mise/tasks/iterm/export` |
| `nix:gcroot` | no | files | no | no | `.mise/tasks/nix/gcroot` |
| `nix:uninstall` | no | yes | yes | no | `.mise/tasks/nix/uninstall` |
| `test:image` | yes | container | no | no | `.mise/tasks/test/image` |
| `test:bootstrap` | no | container | no | no | `.mise/tasks/test/bootstrap` |
| `test:deploy` | no | container | no | no | `.mise/tasks/test/deploy` |
| `docs:build` | no | files | no | no | `.mise/tasks/docs/build` |
| `docs:serve` | no | no | no | no | `.mise/tasks/docs/serve` |

## Baseline risks

- Activation and Nix token setup were duplicated.
- `add-host` created/switched branches, staged files, and committed by default.
- Darwin and Linux target discovery used unrelated implementations.
- Root bootstrap inferred context and retained post-mise orchestration.
- Read-only guarantees were not tested as contracts.
