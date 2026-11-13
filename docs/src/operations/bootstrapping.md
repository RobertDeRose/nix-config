# Bootstrapping

The `bootstrap.sh` script handles everything needed to set up a fresh machine
from zero to a fully configured system.

## One-Liner

```bash
sh -c 'curl -sSfL https://raw.githubusercontent.com/RobertDeRose/nix-config/main/bootstrap.sh | bash -s -- <hostname>'
```

`<hostname>` defaults to `hostname -s` when omitted. Pass it explicitly on a
new Mac, because the factory hostname rarely matches the host directory.

Environment overrides:

| Variable | Default | Purpose |
|----------|---------|---------|
| `REPO` | `RobertDeRose/nix-config` | GitHub repo to clone |
| `BRANCH` | `main` | Branch to clone |
| `NIX_CONFIG_DIR` | `~/workspace/personal/nix-config` | Clone location |

`REPO` and `BRANCH` are also detected from the curl URL when the one-liner is
used.

## Before You Start (macOS)

- **Sign in to the Mac App Store.** Activation installs Bitwarden and other
  `masApps` through `mas`, which needs an App Store session. Without it the
  Homebrew bundle step can fail.
- **Pick the host directory.** `add-host` leaves an existing, committed host
  directory untouched. To replace a Mac with a new one that should share its
  settings, copy `hosts/<arch>-darwin/<old>/` to `hosts/<arch>-darwin/<new>/`
  and commit it before bootstrapping. A hostname with no directory gets the
  bare darwin template.

## What It Does

### macOS

1. Installs **Xcode Command Line Tools** (if missing)
2. Uses the current checkout if run from inside this repo; otherwise reuses or
   clones the repo at `NIX_CONFIG_DIR`
3. Installs **mise** and the `mise-nix` plugin (if missing), then runs
   `mise run nix:init <hostname>`
4. Installs **upstream Nix** (if missing) with the official `nix-installer`
5. Runs `add-host`: if `hosts/<arch>-darwin/<hostname>/` is already committed,
   it does nothing. Otherwise it switches to a `host/<hostname>` branch, copies
   the darwin template, writes `user.nix` (prompting for missing git identity),
   and commits the new host
6. Runs `activate`, which builds the system, moves the installer's
   `/etc/nix/nix.conf` aside, and runs `darwin-rebuild switch`
7. `nix-homebrew` installs and manages Homebrew during activation

### Linux (Ubuntu headless)

1. Installs `git` (if missing) and clones the repo as above
2. Installs mise and runs `mise run nix:init <hostname>`
3. Installs **upstream Nix** (if missing) using the official `nix-installer`
4. Creates `systems/<arch>-linux/<hostname>/` from the linux template (unless
   it is already committed). Linux usernames must be lowercase POSIX names
5. Builds and activates **system-manager** configuration
6. Builds and activates **home-manager** configuration

## After Bootstrap (macOS)

After the first switch, darwin git config signs every commit with an SSH key
from the Bitwarden SSH agent and rewrites `https://github.com/` remotes to SSH.
Before committing or pushing (including `git push -u origin host/<hostname>`):

1. Open Bitwarden, sign in, and unlock it.
2. Enable the SSH agent in Bitwarden's settings.
3. Confirm `ssh -T git@github.com` succeeds.

Day-to-day changes are then applied with:

```bash
mise run nix:switch
```

If the first activation stops with "Unexpected files in /etc", move the listed
files aside (for example
`sudo mv /etc/zshrc /etc/zshrc.before-nix-darwin`) and rerun
`mise run activate <hostname>`.

## CI Mode

Evaluate-only mode comes from `CI=true`, not from the hostname. With it set,
`add-host` skips the branch, prompts, and commit, `nix:trust` is skipped, and
`activate` only evaluates the configuration:

```bash
CI=true ./bootstrap.sh ci-bootstrap
```

GitHub Actions sets `CI=true` automatically. Without it, `./bootstrap.sh
ci-bootstrap` scaffolds, commits, and activates a real `ci-bootstrap` host on
the machine.
