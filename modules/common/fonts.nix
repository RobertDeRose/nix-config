# modules/common/fonts.nix
# Font packages for Darwin system configuration.
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
