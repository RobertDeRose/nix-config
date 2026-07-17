# Task reference

Run `maison tasks` for live discovery and `maison <task> --help` for generated usage.

## Stable machine-management interface

| Task | Purpose | Host state | Sudo | Platforms | Legacy equivalent | Source |
| --- | --- | --- | --- | --- | --- | --- |
| `doctor` | Diagnose repository and machine prerequisites | Read-only | No | All | — | `.mise/tasks/doctor` |
| `plan` | Resolve and preview a host or explicit target | Read-only | No | All | `nix:dry-run` | `.mise/tasks/plan` |
| `apply` | Build the complete selected target, then activate | Changes unless `--no-activate` | During activation | All | `nix:switch`, `nix:debug` | `.mise/tasks/apply` |
| `check` | Run every repository validation check | Read-only | No | All/CI | — | `.mise/tasks/check/_default` |
| `update [input]` | Update all or one flake input, show the lock diff, validate hosts, restore the prior lock on failure | Repository only | No | All | `nix:up` | `.mise/tasks/update` |
| `deploy <destination> [host]` | Build and deploy a Linux host over SSH | Remote changes | Remote sudo may be required | Linux targets | `nix:deploy` | `.mise/tasks/deploy` |
| `rollback [--yes]` | Roll back nix-darwin or deactivate system-manager | Changes | Yes | All | — | `.mise/tasks/rollback` |
| `bootstrap` | Install Nix/Lix after mise is available, validate/create a host, and apply it | Changes | Installer/activation | All | `nix:init` | `.mise/tasks/bootstrap` |

`apply`, `plan`, and `doctor` default to the current short hostname. `apply` and `plan` accept `--host`; `apply` also accepts `--debug` and `--no-activate`. `plan` and all `check:*` tasks are prohibited from invoking activation or sudo.

## Host management

| Task | Purpose | Mutation | Source |
| --- | --- | --- | --- |
| `host:add <hostname>` | Add a validated inventory entry; optionally create override stubs | Configuration files only; commit only with `--commit` | `.mise/tasks/host/add` |
| `host:list` | Show hosts, systems, users, and profiles | Read-only | `.mise/tasks/host/list` |

## Package and application management

| Task | Purpose | Source |
| --- | --- | --- |
| `tool:add <tool> [--version]` | Add/update a mise-owned standalone tool | `.mise/tasks/tool/add` |
| `tool:remove <tool>` | Remove a mise-owned tool | `.mise/tasks/tool/remove` |
| `package:add <package> [--profile <profile>]` | Add a nixpkgs attribute to a profile; defaults to `base` | `.mise/tasks/package/add` |
| `package:remove <package> --profile <profile>` | Remove a profile Nix package | `.mise/tasks/package/remove` |
| `package:search <query>` | Search Mise, nixpkgs, and Homebrew | `.mise/tasks/package/search` |
| `app:add <cask>` | Add a macOS Homebrew cask | `.mise/tasks/app/add` |
| `app:remove <cask>` | Remove a macOS Homebrew cask | `.mise/tasks/app/remove` |
| `cache:package <target>` | Check package outputs against configured binary caches | `.mise/tasks/cache/package` |
| `cache:status [--host <host>]` | Check configured binary-cache endpoint availability | `.mise/tasks/cache/status` |

Mutation commands are transactional where validation can fail, display a Git diff, and do not stage, commit, switch branches, or push.

## Validation subtasks

`check` runs these in order:

| Task | Validation |
| --- | --- |
| `check:shell` | Mise metadata, executable task modes, Bash syntax, Python bytecode, ShellCheck, and shfmt |
| `check:nix` | Flake metadata, all-system `nix flake check --no-build`, and Nix formatting |
| `check:inventory` | Inventory users, hosts, systems, profiles, and overrides |
| `check:packages` | Package data and ownership |
| `check:hosts` | Every Darwin system output and every Linux system/Home Manager output |
| `check:tests` | Mocked task/library regression tests |

## Advanced maintenance

The following remain public for direct maintenance: `nix:clean`, `nix:gc`, `nix:gcroot`, `nix:history`, `nix:repl`, `nix:fmt`, `nix:trust`, `nix:uninstall`, `iterm:export`, `docs:build`, `docs:serve`, `test:bootstrap`, and `test:deploy`.

Hidden helpers include `host:validate`, `package:validate`, `install-nix`, `github-auth`, and `test:image`.

## Compatibility wrappers

These hidden wrappers contain no activation or host-management implementation of their own:

```text
nix:init     → bootstrap
nix:switch   → apply
nix:debug    → apply --debug
nix:dry-run  → plan
nix:deploy   → deploy
nix:up       → update
add-host     → host:add
activate     → apply
```
