{
  pkgs,
  lib,
  username,
  ...
}:
{
  nix = {
    enable = true;
    package = pkgs.nix;
    optimise.automatic = true;

    settings = {
      builders-use-substitutes = true;
      # enable flakes globally
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      # # substituers that will be considered before the official ones(https://cache.nixos.org)
      # substituters = [
      #   "https://nix-community.cachix.org"
      #   "https://cache.nixos.org/"
      # ];
      # trusted-public-keys = [
      #   "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      # ];
      trusted-users = [username];
    };

    # do garbage collection weekly to keep disk usage low
    gc = {
      automatic = true;
      options = "--delete-older-than 7d";
    };
  };
}
