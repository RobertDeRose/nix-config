{ pkgs, ... }:
let
  # OSC 52 clipboard shim for Linux (terminal-based copy via escape sequences)
  osc52-copy = pkgs.writeShellScriptBin "osc52-copy" ''
    set -euo pipefail
    data="$(${pkgs.coreutils}/bin/cat | ${pkgs.coreutils}/bin/base64 | ${pkgs.coreutils}/bin/tr -d '\n')"
    ${pkgs.coreutils}/bin/printf '\033]52;c;%s\a' "$data"
  '';
in
{
  programs.zellij = {
    enable = true;

    settings = {
      simplified_ui = false;
      default_layout = "compact";
      pane_frames = true;
      show_startup_tips = false;
      mouse_mode = true;
      copy_command = if pkgs.stdenv.isDarwin then "pbcopy" else "${osc52-copy}/bin/osc52-copy";

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
}
