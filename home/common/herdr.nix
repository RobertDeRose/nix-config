# Herdr terminal multiplexer for AI agents.
{
  pkgs,
  inputs,
  ...
}:
{
  home.packages = [
    (import ../../nix/packages/custom/llmagents.nix {
      inherit inputs pkgs;
      name = "herdr";
    })
  ];
}
