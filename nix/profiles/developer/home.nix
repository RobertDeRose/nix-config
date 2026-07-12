{
  inputs,
  pkgs,
  packageData,
  ...
}:
{
  home.packages = packageData.profileNixPackages {
    inherit pkgs;
    profile = "developer";
  };

  imports = [
    inputs.worktrunk.homeModules.default
    ../../modules/home/common/direnv.nix
    ../../modules/home/common/helix.nix
    ../../modules/home/common/herdr.nix
    ../../modules/home/common/opencode.nix
    ../../modules/home/common/pi.nix
  ];

  programs.worktrunk = {
    enable = true;
    enableZshIntegration = true;
    enableBashIntegration = true;
  };
}
