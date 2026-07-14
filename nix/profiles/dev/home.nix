{
  pkgs,
  packageData,
  ...
}:
{
  home.packages = packageData.profileNixPackages {
    inherit pkgs;
    profile = "dev";
  };

  imports = [
    ../../modules/home/common/direnv.nix
    ../../modules/home/common/helix.nix
  ];
}
