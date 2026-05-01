# home/darwin.nix
# macOS home-manager entry point.
# Imports shared config + macOS-specific modules.
{
  username,
  pkgs,
  inputs,
  ...
}:
{
  imports = [
    inputs.worktrunk.homeModules.default
    ./common
    ./common/ghostty.nix
    ./common/zed.nix
    ./darwin/ssh.nix
  ];

  home.homeDirectory = "/Users/${username}";

  programs.worktrunk = {
    package = pkgs.writeShellScriptBin "worktrunk" ''
      if [ -x /opt/homebrew/bin/brew ]; then
        brew_bin=/opt/homebrew/bin/brew
      elif [ -x /usr/local/bin/brew ]; then
        brew_bin=/usr/local/bin/brew
      else
        brew_bin=$(command -v brew) || {
          echo "worktrunk wrapper: Homebrew not found" >&2
          exit 127
        }
      fi

      prefix="$($brew_bin --prefix worktrunk)" || exit $?
      exec "$prefix/bin/wt" "$@"
    '';
  };

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
