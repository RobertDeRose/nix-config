# home/darwin.nix
# macOS home-manager entry point.
# Imports shared config + macOS-specific modules.
{ username, ... }: {
  imports = [
    ./common
    ./common/ghostty.nix
  ];

  home.homeDirectory = "/Users/${username}";
}
