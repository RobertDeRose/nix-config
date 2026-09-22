# modules/darwin/config.nix
# nix-darwin-specific Nix daemon settings: caches, GC, trusted users,
# experimental features, and the upstream Nix daemon.
{
  pkgs,
  username,
  ...
}:
let
  cache = import ../common/cache.nix;
in
{
  nixpkgs.config.allowUnfree = true;

  nix = {
    # Use upstream Nix (CppNix) on every Darwin host.
    package = pkgs.nix;
    channel.enable = false;
    optimise.automatic = true;

    settings = {
      builders-use-substitutes = true;
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      trusted-users = [ username ];

      # Bake extra caches into nix.conf so darwin-rebuild can use them without
      # relying on flake-level accept-flake-config behavior.
      extra-substituters = cache.substituters;
      extra-trusted-public-keys = cache.trustedPublicKeys;
      # Upstream Nix 2.24+ setting.
      download-buffer-size = 128 * 1024 * 1024; # 128 MiB (default 64 MiB)
    };

    # Garbage-collect weekly to keep disk usage low
    gc = {
      automatic = true;
      options = "--delete-older-than 7d";
    };
  };
}
