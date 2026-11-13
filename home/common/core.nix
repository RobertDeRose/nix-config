# home/common/core.nix
# Cross-platform CLI tools and programs — works on macOS and Linux.
{
  pkgs,
  ...
}:
{
  home.packages = with pkgs; [
    # archives
    zip
    xz
    unzip

    # utils
    bash # bash 5.x (macOS ships ancient 3.2)
    acli
    jq # lightweight and flexible command-line JSON processor
    pv # monitor data progress through a pipeline
    ripgrep # recursively searches directories for a regex pattern
    yq-go # yaml processor https://github.com/mikefarah/yq

    socat # replacement of openbsd-netcat
    nmap # utility for network discovery and security auditing

    # git tools
    git-absorb # automatic git commit --fixup
    git-filter-repo # fast git history rewriting
    git-trim # trim local tracking branches merged remotely

    # misc
    gnused
    gnutar
    gawk
    zstd

    # nix
    nixfmt
    nixd

    bitwarden-cli
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
  };

  home.sessionVariables = {
    VISUAL = "hx";
    EDITOR = "hx";
    GIT_EDITOR = "hx";
    GIT_SEQUENCE_EDITOR = "hx";
  };

  # Personal scripts — symlinked to ~/.local/bin/
  home.file = {
    ".local/bin/bw-lock" = {
      source = ../../files/scripts/bw-lock;
      executable = true;
    };
    ".local/bin/bw-unlock" = {
      source = ../../files/scripts/bw-unlock;
      executable = true;
    };
    ".local/bin/rund" = {
      source = ../../files/scripts/rund;
      executable = true;
    };
  };
}
