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

  # Linux-only CLI tools.
  home.packages = with pkgs; [
    btop
    pstree
    rlwrap # readline wrapper for CLI programs lacking line editing
    snitch # pretty ui for port users
  ];

  # Use Home Manager's built-in module with the upstream flake's pinned package.
  programs.worktrunk.package = inputs.worktrunk.packages.${pkgs.stdenv.hostPlatform.system}.worktrunk;

  # ------------------------------------------------------------------ #
  # XDG base dirs (Linux desktop standard)
  # ------------------------------------------------------------------ #
  xdg.enable = true;
}
