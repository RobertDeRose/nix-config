# modules/common/overlays.nix
# Temporary package overrides — remove entries as nixpkgs catches up.
# Only imported on Darwin (see nix-core.nix).
{ pkgs, ... }:
{
  nixpkgs.overlays = [ ];
}
