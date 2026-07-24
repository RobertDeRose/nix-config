# Task reference

## Aggregate commands

| Task | Behavior |
| --- | --- |
| `doctor` | Diagnose both ownership layers without mutation |
| `plan` | Run system build preview, then user dry run |
| `apply` | Apply Nix system state, then mise user state |
| `update [input]` | Update flake inputs transactionally, validate, then upgrade user software |
| `deploy <host>` | Deploy Linux system with deploy-rs, then converge remote user state |
| `rollback` | Roll back only the Nix system generation |
| `bootstrap` | Install/repair Nix and converge both layers |
| `check` | Validate data, scripts, tests, and flake outputs |

## System commands

| Task | Behavior |
| --- | --- |
| `system:plan` | `nh darwin build` or build a system-manager closure |
| `system:apply` | `nh darwin switch` or system-manager switch |
| `system:deploy` | deploy-rs Linux system profile |
| `system:history` | List canonical system-profile generations |
| `system:rollback` | Select and activate the previous generation |
| `system:clean [age]` | Remove old system generations and collect the store |

## User commands

| Task | Behavior |
| --- | --- |
| `user:plan` | Preview repository dotfiles and global user bootstrap |
| `user:apply` | Install tools, packages, apps, defaults, and dotfiles |
| `user:status` | Report user-environment drift |
| `user:update` | Show outdated tools, upgrade tools, then upgrade packages |

## Configuration commands

| Task | Behavior |
| --- | --- |
| `host:add` / `host:list` / `host:validate` | Manage inventory |
| `tool:add` / `tool:remove` | Edit global mise tools |
| `package:add` / `package:remove` / `package:search` | Manage bootstrap packages |
| `app:add` / `app:remove` | Manage macOS casks |
| `iterm:export` | Refresh the checked-in iTerm plist |
| `docs:build` / `docs:serve` | Build or serve this book |

Hidden `nix:*` tasks are compatibility aliases to the corresponding `system:*` tasks and contain no separate activation logic.
