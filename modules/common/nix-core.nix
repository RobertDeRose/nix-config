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

      # Bake extra caches into nix.conf so darwin-rebuild and system-manager
      # can use them without --accept-flake-config.
      extra-substituters = [
        "https://cache.nixos.org"
        "https://nix-community.cachix.org"
        "https://cache.numtide.com"
      ];
      extra-trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
      ];
    };

    # Garbage-collect weekly to keep disk usage low
    gc = {
      automatic = true;
      options = "--delete-older-than 7d";
    };
  };
}
