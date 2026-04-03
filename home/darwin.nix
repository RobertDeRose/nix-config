# home/darwin.nix
# macOS home-manager entry point.
# Imports shared config + macOS-specific modules.
{ username, pkgs, ... }: {
  imports = [
    ./common
    ./common/ghostty.nix
    ./common/ssh.nix
  ];

  home.homeDirectory = "/Users/${username}";

  home.packages = [
    pkgs.bitwarden-cli # Bitwarden vault CLI (bw)
  ];
}
