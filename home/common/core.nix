# home/common/core.nix
# Cross-platform CLI tools and programs — works on macOS and Linux.
{ pkgs, inputs, ... }:
let
  llmAgentPkgs = inputs.opencode.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  home.packages =
    with pkgs;
    [
      # archives
      zip
      xz
      unzip

      # utils
      bash # bash 5.x (macOS ships ancient 3.2)
      btop
      acli
      bitwarden-cli
      jq # lightweight and flexible command-line JSON processor
      pstree
      pv # monitor data progress through a pipeline
      ripgrep # recursively searches directories for a regex pattern
      rlwrap # readline wrapper for CLI programs lacking line editing
      tmux
      yq-go # yaml processor https://github.com/mikefarah/yq
      docker-client

      socat # replacement of openbsd-netcat
      nmap # utility for network discovery and security auditing
      snitch # pretty ui for port users

      # git tools
      git-absorb # automatic git commit --fixup
      git-filter-repo # fast git history rewriting
      git-town # higher-level git branch workflow automation
      git-trim # trim local tracking branches merged remotely

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
      usage # required for mise task/tab completion
    ]
    ++ [
      llmAgentPkgs.openspec
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
      shellWrapperName = "y";
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

  # Personal scripts — symlinked to ~/.local/bin/
  home.file = {
    ".local/bin/rund" = {
      source = ../../files/scripts/rund;
      executable = true;
    };
  };
}
