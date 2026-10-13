# home/linux.nix
# Linux home-manager entry point.
# Imports shared config and sets the Linux-specific home directory.
{
  username,
  inputs,
  pkgs,
  ...
}:
{
  imports = [
    ./common
  ];

  home.homeDirectory = "/home/${username}";

  # Use Home Manager's built-in module with the upstream flake's pinned package.
  programs.worktrunk.package = inputs.worktrunk.packages.${pkgs.stdenv.hostPlatform.system}.worktrunk;

  # ------------------------------------------------------------------ #
  # XDG base dirs (Linux desktop standard)
  # ------------------------------------------------------------------ #
  xdg.enable = true;
}
