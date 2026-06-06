# home/common/herdr.nix
# Herdr terminal multiplexer for AI agents.
{ pkgs, inputs, ... }:
{
  home.packages = [
    inputs.llmagents.packages.${pkgs.stdenv.hostPlatform.system}.herdr
  ];
}
