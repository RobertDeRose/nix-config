{ pkgs, ... }:
let
  zellij-copy = pkgs.writeShellScriptBin "zellij-copy" (
    if pkgs.stdenv.isDarwin then
      ''
        exec /usr/bin/pbcopy
      ''
    else
      ''
        set -euo pipefail
        data="$(${pkgs.coreutils}/bin/cat | ${pkgs.coreutils}/bin/base64 | ${pkgs.coreutils}/bin/tr -d '\n')"
        ${pkgs.coreutils}/bin/printf '\033]52;c;%s\a' "$data"
      ''
  );
in
{
  home.packages = [
    pkgs.zellij
    zellij-copy
  ];

  xdg.configFile."zellij/config.kdl".source = ../../dotfiles/zellij/config.kdl;
}
