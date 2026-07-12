{
  user,
  host,
  pkgs,
  packageData,
  ...
}:
{
  imports = [
    ../../../home/common/core.nix
    ../../../home/common/git.nix
    ../../../home/common/htop.nix
    ../../../home/common/shell.nix
    ../../../home/common/zellij.nix
  ];

  home.packages = packageData.hostNixPackages {
    inherit pkgs;
    host = host.name;
  };

  home = {
    username = user.username;
    stateVersion = "25.11";
    enableNixpkgsReleaseCheck = false;
  };

  programs.home-manager.enable = true;
}
