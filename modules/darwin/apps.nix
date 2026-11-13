# modules/darwin/apps.nix
# macOS-only: system-wide nix packages + Homebrew casks/formulae.
# GUI apps and anything macOS-specific live here.
# Cross-platform CLI tools belong in home/common/core.nix instead.
{
  pkgs,
  lib,
  username,
  ...
}:
let
  isAarch64 = pkgs.stdenv.hostPlatform.isAarch64;
in
{
  # System-wide packages available to all users.
  # Prefer home-manager's home.packages for user-level tools.
  environment.systemPackages = with pkgs; [
    bat
    git
  ];

  # Homebrew installation managed declaratively via nix-homebrew.
  # On a fresh machine, nix-darwin will install Homebrew automatically.
  nix-homebrew = {
    enable = true;
    user = username;
    autoMigrate = true; # migrate existing manual Homebrew installs
    # Home Manager supplies the stable Homebrew environment below. Avoid
    # running `brew shellenv` for every interactive zsh process.
    enableZshIntegration = false;
    extraEnv.HOMEBREW_NO_ENV_HINTS = "1";
  };

  homebrew = {
    enable = true;

    onActivation = {
      autoUpdate = false;
      upgrade = false; # only install missing packages, don't upgrade existing ones
      cleanup = "none"; # keep manually installed Homebrew apps/casks
    };

    taps = [
      {
        name = "manaflow-ai/cmux";
        trusted = true;
      }
      {
        name = "modem-dev/tap";
        trusted = true;
      }
      {
        name = "robertderose/tap";
        trusted = true;
      }
      {
        name = "stablyai/orca";
        trusted = true;
      }
    ];

    # brew install — CLI tools that mise can't provide, or that must live in
    # Homebrew's prefix. Prefer home/common/mise.nix for new CLI tools.
    brews = [
      "worktrunk" # Installed via Homebrew to avoid uncached local Rust builds
      "modem-dev/tap/hunk"

      # Apple container stack. services.container-builder and the plugins
      # below expect Homebrew's `container`, so keep all three here.
      "container"
      "robertderose/tap/container-compose-plugin" # `container compose`
      # After install or upgrade, run `container-krun-runtime-setup` (sudo).
      "robertderose/tap/container-krun-runtime"

      "picocom" # serial console
      "wget"
    ];

    # brew install --cask ...
    casks = [
      "dropbox"
      "google-chrome"
      "maccy"

      "raycast" # Launcher (alt/option + space)
      "tailscale-app"
      "vorssaint" # Menu bar system monitor and keep-awake

      # Development
      "balenaetcher"
      "claude"
      "cmux" # Ghostty-based terminal for AI coding agents
      "imageoptim"
      "ghostty"
      "stablyai/orca/orca" # Orca agent IDE; bare `orca` is an unrelated Plotly cask
      "pearcleaner"
      "rectangle"
      "t3-code@nightly" # T3 Code, nightly channel
      "zed"
    ]
    ++ lib.optionals isAarch64 [
      "chatgpt" # aarch64 only
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
      "Numbers: Make Spreadsheets" = 361304891;
      "Pages: Create Documents" = 361309726;
      "Windows App" = 1295203466;
    };
  };
}
