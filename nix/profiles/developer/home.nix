{
  inputs,
  ...
}:
{
  imports = [
    inputs.worktrunk.homeModules.default
    ../../../home/common/direnv.nix
    ../../../home/common/helix.nix
    ../../../home/common/herdr.nix
    ../../../home/common/opencode.nix
    ../../../home/common/pi.nix
  ];

  programs.worktrunk = {
    enable = true;
    enableZshIntegration = true;
    enableBashIntegration = true;
  };
}
