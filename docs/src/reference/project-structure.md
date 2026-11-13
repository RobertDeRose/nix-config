# Project Structure

```
.
├── flake.nix                  # Entry point — flake-parts + easy-hosts
├── flake.lock                 # Pinned input revisions
├── mise.toml                  # Task runner (25 tasks)
├── bootstrap.sh               # One-liner bootstrap (curl | bash)
├── hk.pkl                     # Pre-commit hook config (Pkl language)
│
├── hosts/                     # macOS hosts (auto-discovered by easy-hosts)
│   └── aarch64-darwin/
│       └── <hostname>/
│           ├── default.nix    # System config (required)
│           ├── user.nix       # Username, name, email, GitHub username
│           └── home.nix       # Per-host HM overrides (optional)
│
├── systems/                   # Linux hosts (custom discovery in flake.nix)
│   ├── x86_64-linux/
│   │   └── <hostname>/
│   │       ├── system.nix     # system-manager config
│   │       ├── user.nix       # Username, name, email, GitHub username
│   │       └── home.nix       # Per-host HM overrides (optional)
│   └── aarch64-linux/
│       └── <hostname>/...
│
├── templates/                 # Host templates (copied by add-host task)
│   ├── darwin/
│   │   ├── default.nix
│   │   └── home.nix
│   └── linux/
│       ├── system.nix
│       └── home.nix
│
├── modules/                   # System-level configuration modules
│   ├── common/
│   │   └── cache.nix          # Shared binary cache URLs and public keys
│   ├── darwin/
│   │   ├── config.nix         # nix-darwin Nix daemon settings
│   │   ├── fonts.nix          # Darwin-only system fonts
│   │   ├── system.nix         # macOS defaults (Dock, Finder, trackpad...)
│   │   └── apps.nix           # Homebrew + nix system packages
│   └── linux/
│       └── system.nix         # system-manager: SSH, users, packages
│
├── home/                      # Home-manager (user-level) configuration
│   ├── darwin.nix             # macOS entry point
│   ├── linux.nix              # Linux entry point
│   ├── common/
│   │   ├── default.nix        # Aggregator: imports all shared modules
│   │   ├── core.nix           # CLI tools
│   │   ├── shell.nix          # zsh + starship
│   │   ├── git.nix            # git, gh
│   │   ├── mise.nix           # mise configuration
│   │   ├── helix.nix          # Helix editor
│   │   ├── ghostty.nix        # Ghostty terminal (macOS)
│   │   ├── zed.nix            # Zed editor (macOS)
│   │   └── htop.nix           # htop config
│   └── darwin/
│       └── ssh.nix            # Bitwarden Desktop SSH agent config
│
├── files/
│   ├── scripts/
│   │   └── rund               # Run in disposable Ubuntu container
│   └── workflows/             # macOS Finder Quick Actions
│
├── docs/                      # mdBook documentation (this site)
│   ├── book.toml
│   ├── theme/
│   └── src/
│
└── .github/workflows/
    ├── ci.yml                 # Validate: config eval and build checks
    ├── cache-refresh.yml      # Refresh flake.lock, warm caches, auto-merge
    ├── hk.yml                 # Lint: hk checks on PRs
    └── docs.yml               # Deploy: mdBook to GitHub Pages
```
