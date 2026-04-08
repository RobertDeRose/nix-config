# home/linux.nix
# Linux home-manager entry point.
# Imports shared config and sets the Linux-specific home directory.
{username, ...}: {
  imports = [./common];

  home.homeDirectory = "/home/${username}";

  # ------------------------------------------------------------------ #
  # XDG base dirs (Linux desktop standard)
  # ------------------------------------------------------------------ #
  xdg.enable = true;
}
