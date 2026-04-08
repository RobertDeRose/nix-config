{pkgs, ...}: {
  programs.zellij = {
    enable = true;

    settings = {
      simplified_ui = false;
      default_layout = "compact";
      pane_frames = true;
      show_startup_tips = false;
      mouse_mode = true;
      copy_command = "pbcopy";

      theme = "ayu_mirage";
      themes.ayu_mirage = {
        fg = "#CBCCC6";
        bg = "#1F2430";
        black = "#191E2A";
        red = "#F28779";
        green = "#AAD94C";
        yellow = "#FFD173";
        blue = "#73D0FF";
        magenta = "#D4BFFF";
        cyan = "#95E6CB";
        white = "#CBCCC6";
        orange = "#FFAD66";
      };
    };
  };

  home.packages =
    if pkgs.stdenv.isLinux
    then [
      (pkgs.writeShellScriptBin "pbcopy" ''
        #!/usr/bin/env bash
        set -euo pipefail
        data="$(cat | base64 | tr -d '\n')"
        printf '\033]52;c;%s\a' "$data"
      '')
    ]
    else [];
}
