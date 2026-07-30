# Task reference

## Aggregate commands

| Task | Behavior |
| --- | --- |
| `doctor` | Diagnose both ownership layers without mutation |
| `plan` | Preview the Nix system layer, then the mise user layer |
| `apply` | Apply Nix system state, then mise user state; system failure stops the sequence |
| `update [input] [--check]` | Update flake inputs atomically; optionally run full validation |
| `deploy <host>` | Deploy Linux system state using the configured deployment account (`maison-deploy` by default), then stage source through a root-owned repository transaction and converge remote user state with revision-bound commit/rollback checks |
| `rollback` | Roll back only the Nix system generation |
| `bootstrap [--overlay SOURCE]` | Store or refresh the private overlay source, verify pinned mise and Lix artifacts, install or repair Nix, then converge both layers system-first |
| `check` | Install repository `mise.toml` tools, validate data and scripts, run behavioral tests, and build Nix checks |

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
| `user:plan` | Preview dotfile handoff, packages, tools, preferences, and lock links without mutation |
| `user:apply` | Sanitize live app backups, then apply dotfiles, packages, tools, apps, and preferences; back up explicitly forced conflicts |
| `user:status` | Report user-environment drift |
| `user:update` | Show outdated mise tools, then upgrade those tools |
| `package:update` | Upgrade configured Homebrew formulae |
| `app:update` | Upgrade configured Homebrew casks and Mac App Store apps |

## Configuration commands

| Task | Behavior |
| --- | --- |
| `host:add` | Authoring-only: add a host to the active public or overlay inventory through typed validation and parser-backed TOML edits |
| `host:list` / `host:validate` | Read or validate the active public or overlay inventory |
| `tool:add` / `tool:remove` | Authoring-only: atomically edit global mise tool configuration and locks with parser-backed TOML preservation |
| `package:add` / `package:remove` | Authoring-only: manage common or platform bootstrap package declarations transactionally with parser-backed TOML preservation |
| `package:search` | Search package sources without repository mutation |
| `app:add` / `app:remove` | Authoring-only: manage Apple Silicon macOS cask declarations transactionally with parser-backed TOML preservation |
| `iterm:export` | Refresh the checked-in iTerm plist |
| `docs:build` / `docs:serve` | Load the contributor environment and build or serve this book |

Hidden `nix:*` tasks are compatibility aliases to the corresponding `system:*` tasks and contain no separate activation logic.

Configuration mutation commands parse the complete target TOML before writing, preserve supported comments, quoted keys,
table boundaries, arrays of tables, and CRLF newlines, then validate the edited document before replacing the candidate
file. Malformed or unsupported TOML fails without partially rewriting the repository file.

Repository mutation commands that write checked-in or overlay repository files (`tool:add`, `tool:remove`, `package:add`,
`package:remove`, `app:add`, `app:remove`, `host:add`, and `update`) are authoring-only. They require a Git authoring
checkout for the target repository, acquire one fail-fast local lock, recover incomplete local journals, and then read
mutable state. A deployed snapshot has `.maison-revision` without `.git` and rejects these commands with guidance to use
the public source checkout or private overlay repository. Read-only commands such as plan, status, list, validate, and
search do not take the repository mutation lock or authoring checkout guard.

## Overlay-aware behavior

`--overlay` is a bootstrap flag. After bootstrap, tasks read the saved overlay state from `${XDG_STATE_HOME:-$HOME/.local/state}/maison/overlay.toml`. If the clone contains `inventory.toml`, inventory lookups, `host:add`, system planning, Nix evaluation, and deployment target selection use that overlay file and its sibling `hosts/` tree. Public starter files remain the fallback when no overlay inventory is present. Because `host:add` writes the active inventory repository, it checks the overlay clone for Git authoring evidence when an overlay inventory is active.

## Verified bootstrap artifacts

Bootstrap artifact metadata is checked in at `bootstrap/artifacts.toml`. Maison downloads the selected mise or Lix artifact to disk, verifies its SHA-256 digest for the current supported system, then executes or installs only that verified local file. The remote deployment mise fallback uses the same repository metadata.
