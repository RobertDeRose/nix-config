# home/darwin.nix
# macOS home-manager entry point.
# Imports shared config and sets the macOS-specific home directory.
{ username, ... }: {
  imports = [ ./common ];

  home.homeDirectory = "/Users/${username}";
}
