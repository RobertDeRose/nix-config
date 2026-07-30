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
| `host:add` / `host:list` / `host:validate` | Manage the active public or overlay inventory through typed validation and parser-backed TOML edits |
| `tool:add` / `tool:remove` | Atomically edit global mise tool configuration and locks with parser-backed TOML preservation |
| `package:add` / `package:remove` / `package:search` | Manage common or platform bootstrap packages transactionally with parser-backed TOML preservation |
| `app:add` / `app:remove` | Manage Apple Silicon macOS casks transactionally with parser-backed TOML preservation |
| `iterm:export` | Refresh the checked-in iTerm plist |
| `docs:build` / `docs:serve` | Load the contributor environment and build or serve this book |

Hidden `nix:*` tasks are compatibility aliases to the corresponding `system:*` tasks and contain no separate activation logic.

Configuration mutation commands parse the complete target TOML before writing, preserve supported comments, quoted keys,
table boundaries, arrays of tables, and CRLF newlines, then validate the edited document before replacing the candidate
file. Malformed or unsupported TOML fails without partially rewriting the repository file.

## Overlay-aware behavior

`--overlay` is a bootstrap flag. After bootstrap, tasks read the saved overlay state from `${XDG_STATE_HOME:-$HOME/.local/state}/maison/overlay.toml`. If the clone contains `inventory.toml`, inventory lookups, `host:add`, system planning, Nix evaluation, and deployment target selection use that overlay file and its sibling `hosts/` tree. Public starter files remain the fallback when no overlay inventory is present.

## Verified bootstrap artifacts

Bootstrap artifact metadata is checked in at `bootstrap/artifacts.toml`. Maison downloads the selected mise or Lix artifact to disk, verifies its SHA-256 digest for the current supported system, then executes or installs only that verified local file. The remote deployment mise fallback uses the same repository metadata.
