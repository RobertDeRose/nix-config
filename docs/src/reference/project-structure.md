# Project Structure

```
.
├── flake.nix                  # Entry point — flake-parts + easy-hosts
├── flake.lock                 # Pinned input revisions
├── mise.toml                  # Task runner (30+ tasks)
├── bootstrap.sh               # One-liner bootstrap (curl | bash)
├── hk.pkl                     # Pre-commit hook config (Pkl language)
│
├── hosts/                     # macOS hosts (auto-discovered by easy-hosts)
│   ├── aarch64-darwin/
│   │   └── <hostname>/
│   │       ├── default.nix    # System config (required)
│   │       ├── user.nix       # Username + email (required)
│   │       └── home.nix       # Per-host HM overrides (optional)
│   └── x86_64-darwin/
│       └── <hostname>/...
│
├── systems/                   # Linux hosts (custom discovery in flake.nix)
│   ├── x86_64-linux/
│   │   └── <hostname>/
│   │       ├── system.nix     # system-manager config
│   │       ├── user.nix       # Username + email
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
│   │   ├── nix-core.nix       # Nix daemon, caches, GC, Lix/CppNix
│   │   ├── fonts.nix          # Shared fonts
│   │   └── overlays.nix       # Temporary nixpkgs patches
│   ├── darwin/
│   │   ├── system.nix         # macOS defaults (Dock, Finder, trackpad...)
│   │   ├── apps.nix           # Homebrew + nix system packages
│   │   └── iterm2.nix         # iTerm2 plist management
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
│   │   ├── git.nix            # git, gh, lazygit
│   │   ├── direnv.nix         # direnv + nix-direnv + mise
│   │   ├── helix.nix          # Helix editor
│   │   ├── zellij.nix         # Zellij multiplexer
│   │   ├── ghostty.nix        # Ghostty terminal (macOS)
│   │   ├── zed.nix            # Zed editor (macOS)
│   │   ├── htop.nix           # htop config
│   │   └── opencode.nix       # OpenCode AI agent
│   └── darwin/
│       └── ssh.nix            # Bitwarden SSH agent
│
├── config/
│   └── iterm2/
│       └── com.googlecode.iterm2.plist  # Exported iTerm2 preferences
│
├── files/
│   ├── scripts/
│   │   ├── clean_git_branches # Delete merged git branches
│   │   └── rund               # Run in disposable Ubuntu container
│   └── workflows/             # macOS Finder Quick Actions
│
├── docs/                      # mdBook documentation (this site)
│   ├── book.toml
│   ├── theme/
│   └── src/
│
└── .github/workflows/
    ├── ci.yml                 # Validate: flake check + build configs
    ├── hk.yml                 # Lint: hk checks on PRs
    └── docs.yml               # Deploy: mdBook to GitHub Pages
```
