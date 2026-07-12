# Herdr terminal multiplexer for AI agents.
{
  pkgs,
  inputs,
  ...
}:
{
  home.packages = [
    (import ../../../packages/custom/llmagents.nix {
      inherit inputs pkgs;
      name = "herdr";
    })
  ];
}
