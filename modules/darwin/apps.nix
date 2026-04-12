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
      autoUpdate = true;
      upgrade = false; # only install missing packages, don't upgrade existing ones
      cleanup = "zap"; # remove anything not listed below
    };

    taps = [
      "macos-fuse-t/cask"
    ];

    # brew install ...
    # brews = [];

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

    # App Store apps via mas — install manually first so Apple has a purchase record.
    masApps = {
      Amphetamine = 937984704;
      Bitwarden = 1352778147;
    };
  };
}
