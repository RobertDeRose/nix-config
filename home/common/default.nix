# home/common/default.nix
# Shared home-manager config — imported by both home/darwin.nix and home/linux.nix.
{ username, ... }:
{
  imports = [
    ./core.nix
    ./git.nix
    ./mise.nix
    ./helix.nix
    ./herdr.nix
    ./htop.nix
    ./shell.nix
  ];

  home = {
    inherit username;
    # homeDirectory is set per-platform in home/darwin.nix and home/linux.nix
    stateVersion = "25.11";
    # We started with 25.11 but using unstable for packages
    enableNixpkgsReleaseCheck = false;
  };

  programs.worktrunk = {
    enable = true;
    enableZshIntegration = true;
    enableBashIntegration = true;
  };

  programs.home-manager.enable = true;
}
