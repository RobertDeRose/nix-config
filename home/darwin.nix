# home/darwin.nix
# macOS home-manager entry point.
# Imports shared config + macOS-specific modules.
{
  username,
  pkgs,
  ...
}:
{
  imports = [
    ./common
    ./common/ghostty.nix
    ./common/zed.nix
    ./darwin/ssh.nix
  ];

  home.homeDirectory = "/Users/${username}";

  fonts.fontconfig.enable = true;

  home.packages = [
    pkgs.bitwarden-cli # Bitwarden vault CLI (bw)
  ];
}
