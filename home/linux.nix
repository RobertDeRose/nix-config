# home/linux.nix
# Linux home-manager entry point.
# Imports shared config and sets the Linux-specific home directory.
# Add Linux-specific programs (e.g. i3, rofi, picom) here.
{ username, pkgs, lib, ... }: {
  imports = [ ./common ];

  home.homeDirectory = "/home/${username}";

  # ------------------------------------------------------------------ #
  # Linux-specific packages
  # ------------------------------------------------------------------ #
  home.packages = with pkgs; [
    xclip   # clipboard CLI tool
    xdotool # X11 automation
  ];

  # ------------------------------------------------------------------ #
  # XDG base dirs (Linux desktop standard)
  # ------------------------------------------------------------------ #
  xdg.enable = true;

  # ------------------------------------------------------------------ #
  # Example: uncomment to enable a window-manager setup
  # ------------------------------------------------------------------ #
  # xsession.windowManager.i3.enable = true;
}
