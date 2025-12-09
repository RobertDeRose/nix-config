{pkgs, ...}: {
  home.packages = with pkgs; [
    # archives
    zip
    xz
    unzip

    # utils
    btop
    fzf # A command-line fuzzy finder
    jq # A lightweight and flexible command-line JSON processor
    ripgrep # recursively searches directories for a regex pattern
    tmux
    yq-go # yaml processor https://github.com/mikefarah/yq
    oh-my-zsh
    zsh-powerlevel10k

    socat # replacement of openbsd-netcat
    nmap # A utility for network discovery and security auditing

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
    # modern vim
    neovim = {
      enable = true;
      defaultEditor = true;
      vimAlias = true;
    };

    # A modern replacement for ‘ls’
    # useful in bash/zsh prompt, not in nushell.
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

    # skim provides a single executable: sk.
    # Basically anywhere you would want to use grep, try sk instead.
    skim = {
      enable = true;
      enableBashIntegration = true;
    };
  };
}
