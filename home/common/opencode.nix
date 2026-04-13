# home/common/opencode.nix
# OpenCode AI coding agent configuration.
# See https://opencode.ai/docs/config/ for available settings.
{ pkgs, ... }:
let
  # opencode is in nixpkgs meta.badPlatforms for x86_64-darwin
  unsupported = pkgs.stdenv.hostPlatform.isx86_64 && pkgs.stdenv.hostPlatform.isDarwin;
in
{
  programs.opencode = {
    enable = !unsupported;
  };
}
