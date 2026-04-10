# modules/linux/system.nix
# Shared system-manager config for headless Ubuntu servers.
# Uses NixOS-style module options, applied via system-manager.
{
  pkgs,
  username,
  githubUsername,
  hostname,
  ...
}: {
  # Allow running on non-NixOS distros
  system-manager.allowAnyDistro = true;

  # ------------------------------------------------------------------ #
  # Locale / Time / Hostname
  # ------------------------------------------------------------------ #
  environment.etc = {
    "hostname".text = "${hostname}\n";
    "timezone".text = "America/New_York\n";
    "default/locale".text = "LANG=en_US.UTF-8\n";
  };

  # ------------------------------------------------------------------ #
  # Common system packages
  # ------------------------------------------------------------------ #
  environment.systemPackages = with pkgs; [
    bat
    eza
    fastfetch
    git
    mise
    curl
    wget
  ];

  # ------------------------------------------------------------------ #
  # SSH
  # ------------------------------------------------------------------ #
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
      AuthorizedKeysCommand = "${pkgs.writeShellScript "github-authorized-keys" ''
        #!/usr/bin/env bash
        set -euo pipefail

        requested_user="''${1:-}"
        if [ "$requested_user" != "${username}" ]; then
          exit 0
        fi

        exec ${pkgs.curl}/bin/curl -fsSL "https://github.com/${githubUsername}.keys"
      ''} %u";
      AuthorizedKeysCommandUser = "root";
      AuthorizedKeysFile = "none";
    };
  };

  # ------------------------------------------------------------------ #
  # User
  # ------------------------------------------------------------------ #
  users.users."${username}" = {
    isNormalUser = true;
    home = "/home/${username}";
    shell = pkgs.zsh;
    ignoreShellProgramCheck = true;
    extraGroups = ["wheel" "docker"];
  };
}
