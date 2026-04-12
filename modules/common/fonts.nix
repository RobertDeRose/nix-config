# modules/common/fonts.nix
# Shared font packages — imported by both Darwin and NixOS system modules.
{ pkgs, ... }:
{
  fonts.packages = with pkgs; [
    material-design-icons
    font-awesome
    nerd-fonts.dejavu-sans-mono
    nerd-fonts.fira-code
    nerd-fonts.meslo-lg
    nerd-fonts.symbols-only
  ];
}
