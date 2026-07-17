# Cross-platform Zsh and Starship configuration.
{
  config,
  pkgs,
  lib,
  ...
}:
{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    dotDir = config.home.homeDirectory;
    initContent = ''
      source ${../../../../dotfiles/zsh/functions.zsh}
      source ${../../../../dotfiles/zsh/aliases.zsh}
      source ${../../../../dotfiles/zsh/interactive.zsh}
      source ${../../../../dotfiles/zsh/integrations.zsh}
      if command -v maison >/dev/null 2>&1 && command -v usage >/dev/null 2>&1; then
        source <(maison completion zsh)
      fi
    '';
    plugins = [
      {
        name = "zsh-syntax-highlighting";
        src = "${pkgs.zsh-syntax-highlighting}/share/zsh-syntax-highlighting";
      }
      {
        name = "zsh-autosuggestions";
        src = "${pkgs.zsh-autosuggestions}/share/zsh-autosuggestions";
      }
    ];
  };

  home.sessionPath = [
    "${config.home.homeDirectory}/.local/bin"
  ]
  ++ lib.optionals pkgs.stdenv.isLinux [
    "/home/linuxbrew/.linuxbrew/bin"
    "/home/linuxbrew/.linuxbrew/sbin"
    "/run/current-system/sw/bin"
    "${config.home.homeDirectory}/.nix-profile/bin"
    "${config.home.homeDirectory}/.local/state/nix/profiles/profile/bin"
  ]
  ++ lib.optionals pkgs.stdenv.isDarwin [
    "/opt/homebrew/bin"
    "/opt/homebrew/sbin"
  ];

  programs.starship = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    settings = builtins.fromTOML (builtins.readFile ../../../../dotfiles/starship/starship.toml);
  };
}
