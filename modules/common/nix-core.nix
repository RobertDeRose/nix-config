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

  # direnv 2.37.1 test-fish gets killed by macOS SIP/sandbox.
  # Skip the check phase until upstream fixes the build.
  # NOTE: this module is currently only imported on Darwin (see flake.nix perClass).
  nixpkgs.overlays = [
    (_final: prev: {
      direnv = prev.direnv.overrideAttrs (_: {
        doCheck = false;
      });
    })
  ];

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
