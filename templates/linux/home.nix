{ pkgs, ... }:
{
  # Host-specific Linux home-manager overrides.
  # This file is imported automatically when present at:
  #   systems/<arch>-linux/<hostname>/home.nix
  #
  # Per-host user packages (merged with the global list in home/common/core.nix):
  #   home.packages = with pkgs; [ ... ];
  #
  # Per-host shell aliases (merged with the global list in home/common/shell.nix):
  #   home.shellAliases = { myalias = "cd ~/my/dir"; };
}
