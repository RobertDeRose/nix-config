# home/darwin.nix
# macOS home-manager entry point.
# Imports shared config + macOS-specific modules.
{
  username,
  pkgs,
  lib,
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

  programs.worktrunk = {
    # Homebrew's opt symlink is stable across formula upgrades; avoid the
    # `brew --prefix` subprocess in every interactive shell.
    enableZshIntegration = lib.mkForce false;
    package = pkgs.writeShellScriptBin "worktrunk" ''
      for wt in /opt/homebrew/opt/worktrunk/bin/wt /usr/local/opt/worktrunk/bin/wt; do
        if [ -x "$wt" ]; then
          exec "$wt" "$@"
        fi
      done

      echo "worktrunk wrapper: Homebrew worktrunk not found" >&2
      exit 127
    '';
  };

  # Worktrunk's shell integration is stable until the Homebrew wt binary
  # changes. Cache it after the first shell instead of invoking wt every time.
  programs.zsh.initContent = lib.mkAfter ''
    if command -v worktrunk >/dev/null 2>&1 && command -v wt >/dev/null 2>&1; then
      worktrunk_wt_bin="$(whence -p wt 2>/dev/null)"
      worktrunk_cache_dir="''${XDG_CACHE_HOME:-$HOME/.cache}/worktrunk"
      worktrunk_cache="$worktrunk_cache_dir/init.zsh"
      if [[ ! -s "$worktrunk_cache" ||
        ( -n "$worktrunk_wt_bin" && "$worktrunk_wt_bin" -nt "$worktrunk_cache" ) ]]; then
        mkdir -p "$worktrunk_cache_dir"
        worktrunk_cache_tmp="$worktrunk_cache.$$"
        if worktrunk config shell init zsh >| "$worktrunk_cache_tmp"; then
          mv -f "$worktrunk_cache_tmp" "$worktrunk_cache"
        else
          rm -f "$worktrunk_cache_tmp"
        fi
      fi
      if [[ -s "$worktrunk_cache" ]]; then
        source "$worktrunk_cache"
      else
        eval "$(worktrunk config shell init zsh)"
      fi
    fi
  '';

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
