{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.homebrew;
  setupHomebrew = config.system.activationScripts.setup-homebrew.text;
  homebrewPath = lib.concatStringsSep ":" [
    "${pkgs.mas}/bin"
    "${cfg.prefix}/bin"
    "${cfg.prefix}/sbin"
    "/usr/local/bin"
    "/usr/bin"
    "/bin"
    "/usr/sbin"
    "/sbin"
  ];
in
{
  config = lib.mkIf cfg.enable {
    system.activationScripts.homebrew.text = lib.mkForce ''
      ${setupHomebrew}

      # Homebrew Bundle
      echo >&2 "Homebrew bundle..."
      if [ -f "${cfg.prefix}/bin/brew" ]; then
        PATH="${lib.makeBinPath [ pkgs.mas ]}:${cfg.prefix}/bin:$PATH" \
        HOMEBREW_PATH="${homebrewPath}" \
        sudo \
          --preserve-env=PATH,HOMEBREW_PATH \
          --user=${lib.escapeShellArg cfg.user} \
          --set-home \
          env \
          ${cfg.onActivation.brewBundleCmd}
      else
        echo -e "\e[1;31merror: Homebrew is not installed, skipping...\e[0m" >&2
      fi
    '';
  };
}
