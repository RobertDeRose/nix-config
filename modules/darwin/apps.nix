# modules/darwin/apps.nix
# macOS-only: system-wide nix packages + Homebrew casks/formulae.
# GUI apps and anything macOS-specific live here.
# Cross-platform CLI tools belong in home/common/core.nix instead.
{ pkgs, ... }:
{
  # System-wide packages available to all users.
  # Prefer home-manager's home.packages for user-level tools.
  environment.systemPackages = with pkgs; [
    bat
    devenv
    eza
    git
    fastfetch
  ];

  # NOTE: Homebrew must be installed manually first: https://brew.sh
  # The init mise task handles this automatically on a fresh machine.
  homebrew = {
    enable = true;

    onActivation = {
      autoUpdate = false;
      upgrade = false; # only install missing packages, don't upgrade existing ones
      cleanup = "zap"; # remove anything not listed below
    };

    taps = [
      "macos-fuse-t/cask"
    ];

    # brew install — CLI tools that aren't in nixpkgs (or are marked EOL there)
    brews = [
      "container" # Apple's native macOS container runtime
      "container-compose" # Docker Compose-like tool for Apple containers
      "lima" # Linux VMs on macOS (nixpkgs version is EOL)
    ];

    # brew install --cask ...
    casks = [
      "dropbox"
      "google-chrome"
      "maccy"

      "anki" # Memory training
      "iina" # Video player
      "raycast" # Launcher (alt/option + space)
      "stats" # System monitor

      # Development
      "atuin-desktop"
      "balenaetcher"
      "chatgpt"
      "claude"
      "cmux" # Ghostty-based terminal for AI coding agents
      "imageoptim"
      "insomnia" # REST client
      "ghostty"
      "iterm2"
      "macos-fuse-t/cask/fuse-t"
      "macos-fuse-t/cask/fuse-t-sshfs"
      "obsidian"
      "pearcleaner"
      "rectangle"
      "zed"
    ];

    # App Store apps via mas.
    # KNOWN ISSUE: mas 6.0.1 `mas get` (used by brew bundle) bypasses the real
    # App Store flow and doesn't write com.apple.appstore.metadata xattrs, so
    # Spotlight never indexes the ADAM ID. Apps first-installed via `mas get`
    # will harmlessly re-download on every switch. Apps installed manually
    # through the App Store first (e.g. Amphetamine, Windows App) are fine.
    # iOS-on-Mac apps (e.g. Kasa Smart) are also invisible — manage manually.
    masApps = {
      Amphetamine = 937984704;
      Bitwarden = 1352778147;
      "Keynote: Design Presentations" = 361285480;
      "Numbers: Make Spreadsheets" = 361304891;
      "Pages: Create Documents" = 361309726;
      "Windows App" = 1295203466;
    };
  };
}
