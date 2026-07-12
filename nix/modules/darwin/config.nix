# nix/modules/darwin/config.nix
# nix-darwin-specific Nix daemon settings: caches, GC, trusted users,
# experimental features, and Lix/CppNix selection.
{
  pkgs,
  lib,
  user,
  host,
  ...
}:
let
  cache = import ../common/cache.nix {
    personal = host.features.personalCache;
  };
  useCppNix = pkgs.stdenv.hostPlatform.isDarwin && pkgs.stdenv.hostPlatform.isx86_64;
in
{
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
      trusted-users = [ user.username ];

      # Bake extra caches into nix.conf so darwin-rebuild can use them without
      # relying on flake-level accept-flake-config behavior.
      extra-substituters = cache.substituters;
      extra-trusted-public-keys = cache.trustedPublicKeys;
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
