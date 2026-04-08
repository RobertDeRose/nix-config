# home/common/core.nix
# Cross-platform CLI tools and programs — works on macOS and Linux.
{
  pkgs,
  lib,
  ...
}: {
  home.packages = with pkgs; [
    # archives
    zip
    xz
    unzip

    # utils
    btop
    jq # lightweight and flexible command-line JSON processor
    ripgrep # recursively searches directories for a regex pattern
    tmux
    yq-go # yaml processor https://github.com/mikefarah/yq

    socat # replacement of openbsd-netcat
    nmap # utility for network discovery and security auditing

    # misc
    gnused
    gnutar
    gawk
    zstd

    # nix
    nixpkgs-fmt
    nixd

    # productivity
    glow # markdown previewer in terminal
  ];

  programs = {
    # command-line fuzzy finder
    fzf = {
      enable = true;
      enableZshIntegration = true;
    };

    # modern replacement for 'ls'
    eza = {
      enable = true;
      git = true;
      icons = "auto";
      enableZshIntegration = true;
    };

    # terminal file manager
    yazi = {
      enable = true;
      enableZshIntegration = true;
      settings = {
        manager = {
          show_hidden = true;
          sort_dir_first = true;
        };
      };
    };
  };

  home.sessionVariables = {
    VISUAL = "hx";
    EDITOR = "hx";
    GIT_EDITOR = "hx";
    GIT_SEQUENCE_EDITOR = "hx";
  };
}
