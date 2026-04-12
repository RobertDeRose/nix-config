# modules/common/nix-core.nix
# Shared Nix daemon settings — works on both nix-darwin and NixOS.
{
  pkgs,
  lib,
  username,
  ...
}:
{
  imports = [ ./overlays.nix ];

  nixpkgs.config.allowUnfree = true;

  nix = {
    package = pkgs.nix;
    optimise.automatic = true;

    settings = {
      builders-use-substitutes = true;
      download-buffer-size = 128 * 1024 * 1024; # 128 MiB (default is 64 MiB)
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
