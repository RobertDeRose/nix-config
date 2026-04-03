# home/common/default.nix
# Shared home-manager config — imported by both home/darwin.nix and home/linux.nix.
{ username, ... }: {
  imports = [
    ./core.nix
    ./shell.nix
    ./git.nix
    ./direnv.nix
  ];

  home = {
    inherit username;
    # homeDirectory is set per-platform in home/darwin.nix and home/linux.nix
    stateVersion = "25.11";
  };

  programs.home-manager.enable = true;
  fonts.fontconfig.enable      = true;
}
