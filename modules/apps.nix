{ pkgs, ... }:
{
  ##########################################################################
  #
  #  Install all apps and packages here.
  #
  ##########################################################################

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;
  # nixpkgs.overlays = [ nix-vscode-extensions.overlays.default ];

  # Install packages from nix's official package repository.
  #
  # The packages installed here are available to all users, and are reproducible across machines, and are rollbackable.
  # But on macOS, it's less stable than homebrew.
  #
  # Related Discussion: https://discourse.nixos.org/t/darwin-again/29331
  environment.defaultPackages = with pkgs; [
    bat
    devenv
    eza
    git
    just # use Justfile to simplify nix-darwin's commands
    neovim
  ];
  environment.variables.EDITOR = "nvim";

  # TODO To make this work, homebrew need to be installed manually, see https://brew.sh
  #
  # The apps installed by homebrew are not managed by nix, and not reproducible!
  # But on macOS, homebrew has a much larger selection of apps than nixpkgs, especially for GUI apps!
  homebrew = {
    enable = true;

    onActivation = {
      autoUpdate = true; # Fetch the newest stable branch of Homebrew's git repo
      upgrade = true; # Upgrade outdated casks, formulae, and App Store apps
      # 'zap': uninstalls all formulae(and related files) not listed in the generated Brewfile
      cleanup = "zap";
    };

    # Applications to install from Mac App Store using mas.
    # You need to install all these Apps manually first so that your apple account have records for them.
    # otherwise Apple Store will refuse to install them.
    # For details, see https://github.com/mas-cli/mas
    # masApps = {
    #   Amphetamine = 937984704;
    #   Bitwarden = 1352778147;
    #   Keynote = 409183694;
    #   Numbers = 409203825;
    #   Pages = 409201541;
    #   Windows = 1295203466;
    #   Xcode = 497799835;
    # };

    taps = [
      "macos-fuse-t/cask"
    ];

    # `brew install`
    # brews = [];

    # `brew install --cask`
    # TODO Feel free to add your favorite apps here.
    casks = [
      "dropbox"
      "google-chrome"
      "maccy"

      "anki" # Memory training app
      "iina" # video player
      "raycast" # (HotKey: alt/option + space)search, calculate and run scripts(with many plugins)
      "stats" # beautiful system monitor

      # Development
      "atuin-desktop"
      "balenaetcher"
      "imageoptim"
      "insomnia" # REST client
      "iterm2"
      "macos-fuse-t/cask/fuse-t"
      "macos-fuse-t/cask/fuse-t-sshfs"
      "obsidian"
      "pearcleaner"
      "rectangle"
      "visual-studio-code"
      "zed"
    ];
  };
}
