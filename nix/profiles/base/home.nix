{
  user,
  host,
  pkgs,
  packageData,
  ...
}:
{
  imports = [
    ../../modules/home/common/core.nix
    ../../modules/home/common/git.nix
    ../../modules/home/common/htop.nix
    ../../modules/home/common/mise.nix
    ../../modules/home/common/shell.nix
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
