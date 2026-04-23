# home/common/opencode.nix
# OpenCode AI coding agent configuration.
# See https://opencode.ai/docs/config/ for available settings.
{
  pkgs,
  inputs,
  ...
}:
let
  opencodePkg = inputs.opencode.packages.${pkgs.stdenv.hostPlatform.system}.opencode;
in
{
  programs.opencode = {
    enable = true;
    package = opencodePkg;
  };
}
