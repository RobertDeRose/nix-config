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

  # Finder Quick Actions — right-click a folder to open in a terminal
  home.file = {
    "Library/Services/Open in Ghostty.workflow" = {
      source = ../files/workflows + "/Open in Ghostty.workflow";
      recursive = true;
    };
    "Library/Services/Open in cmux.workflow" = {
      source = ../files/workflows + "/Open in cmux.workflow";
      recursive = true;
    };
    "Library/Services/Open in iTerm2.workflow" = {
      source = ../files/workflows + "/Open in iTerm2.workflow";
      recursive = true;
    };
  };
}
