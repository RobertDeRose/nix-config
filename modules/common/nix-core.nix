# modules/common/nix-core.nix
# Shared Nix daemon settings — works on both nix-darwin and NixOS.
{
  pkgs,
  lib,
  username,
  ...
}:
{
  nixpkgs.config.allowUnfree = true;

  nix = {
    package = pkgs.nix;
    optimise.automatic = true;

    settings = {
      builders-use-substitutes = true;
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      trusted-users = [ username ];
    };

    # Garbage-collect weekly to keep disk usage low
    gc = {
      automatic = true;
      options = "--delete-older-than 7d";
    };
  };
}
