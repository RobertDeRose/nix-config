{
  user,
  pkgs,
  packageData,
  ...
}:
{
  home.packages = packageData.profileNixPackages {
    inherit pkgs;
    profile = "linux-server";
  };

  home.homeDirectory = "/home/${user.username}";
  xdg.enable = true;
}
