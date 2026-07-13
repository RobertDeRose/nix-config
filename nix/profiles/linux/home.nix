{
  user,
  pkgs,
  packageData,
  ...
}:
{
  home.packages = packageData.profileNixPackages {
    inherit pkgs;
    profile = "linux";
  };

  home.homeDirectory = "/home/${user.username}";
  xdg.enable = true;
}
