# home/common/opencode.nix
# OpenCode AI coding agent configuration.
# See https://opencode.ai/docs/config/ for available settings.
{
  pkgs,
  inputs,
  ...
}:
let
  opencodePkg = import ../../nix/packages/custom/llmagents.nix {
    inherit inputs pkgs;
    name = "opencode";
  };
in
{
  programs.opencode = {
    enable = true;
    package = opencodePkg;
  };
}
