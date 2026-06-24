{
  config,
  pkgs,
  ...
}:
{
  # Host-specific Linux home-manager overrides.
  # This file is imported automatically when present at:
  #   systems/<arch>-linux/<hostname>/home.nix

  home.packages = with pkgs; [
    uv
  ];

  systemd.user.services.unsloth-studio = {
    Unit = {
      Description = "Unsloth Studio LLM Interface";
      After = [ "network.target" ];
    };

    Service = {
      Type = "simple";
      ExecStart = "${pkgs.uv}/bin/uvx unsloth studio -H 0.0.0.0 -p 8888";
      Restart = "always";
      RestartSec = 5;
      WorkingDirectory = config.home.homeDirectory;
    };

    Install.WantedBy = [ "default.target" ];
  };
}
