# modules/common/nix-core.nix
# Shared Nix daemon settings — works on both nix-darwin and NixOS.
{
  pkgs,
  lib,
  username,
  ...
}:
let
  useCppNix = pkgs.stdenv.hostPlatform.isDarwin && pkgs.stdenv.hostPlatform.isx86_64;
in
{
  imports = [ ./overlays.nix ];

  nixpkgs.config.allowUnfree = true;

  nix = {
    # Lix on all platforms except x86_64-darwin (Lix dropped Intel Mac support)
    package = if useCppNix then pkgs.nix else pkgs.lixPackageSets.latest.lix;
    channel.enable = false;
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
    }
    // lib.optionalAttrs useCppNix {
      # CppNix 2.24+ only — Lix doesn't recognise this setting
      download-buffer-size = 128 * 1024 * 1024; # 128 MiB (default 64 MiB)
    };

    # Garbage-collect weekly to keep disk usage low
    gc = {
      automatic = true;
      options = "--delete-older-than 7d";
    };
  };
}
