# modules/linux/system.nix
# Shared system-manager config for headless Ubuntu servers.
# Uses NixOS-style module options, applied via system-manager.
{
  pkgs,
  username,
  githubUsername,
  hostname,
  ...
}:
let
  cache = import ../common/cache.nix;
  githubAuthorizedKeysScript = pkgs.writeShellScript "github-authorized-keys" ''
    set -euo pipefail

    requested_user="''${1:-}"
    if [ "$requested_user" != "${username}" ]; then
      exit 0
    fi

    target_file="/etc/ssh/authorized_keys.d/${username}"
    tmp_file="$(${pkgs.coreutils}/bin/mktemp "$(dirname "$target_file")/${username}.XXXXXX")"
    trap '${pkgs.coreutils}/bin/rm -f "$tmp_file"' EXIT

    # Refresh the configured user's authorized keys from GitHub.
    if ${pkgs.curl}/bin/curl --connect-timeout 5 --max-time 10 -fsSL "https://github.com/${githubUsername}.keys" > "$tmp_file"; then
      if [ ! -s "$tmp_file" ]; then
        exit 1
      fi
      install -m 0644 "$tmp_file" "$target_file"
      exit 0
    fi

    # Keep the last successfully installed file if GitHub is unavailable.
    if [ -s "$target_file" ]; then
      exit 0
    fi

    exit 1
  '';
in
{
  # Allow running on non-NixOS distros
  system-manager.allowAnyDistro = true;

  environment.etc."nix/nix.custom.conf" = {
    text = ''
      extra-substituters = ${builtins.concatStringsSep " " cache.substituters}
      extra-trusted-public-keys = ${builtins.concatStringsSep " " cache.trustedPublicKeys}
      extra-trusted-users = root ${username}
    '';
    replaceExisting = true;
  };

  # ------------------------------------------------------------------ #
  # Locale / Time / Hostname
  # ------------------------------------------------------------------ #
  environment.etc = {
    "hostname" = {
      text = "${hostname}\n";
      replaceExisting = true;
    };
    "timezone" = {
      text = "America/New_York\n";
      replaceExisting = true;
    };
    "default/locale" = {
      text = "LANG=en_US.UTF-8\n";
      replaceExisting = true;
    };
  };

  # ------------------------------------------------------------------ #
  # Common system packages
  # ------------------------------------------------------------------ #
  environment.systemPackages = with pkgs; [
    bat
    eza
    gitMinimal
    curl
    wget
  ];

  # ------------------------------------------------------------------ #
  # SSH
  # ------------------------------------------------------------------ #
  services.openssh = {
    enable = true;
    settings = {
      # Do not harden existing host login policy by default during remote
      # bootstrap. Preserve the distro's current root/password SSH behavior
      # unless a specific host opts into stricter settings.
    };
  };

  systemd.services.prefill-authorized-keys = {
    wantedBy = [ "system-manager.target" ];
    after = [
      "network-online.target"
      "ssh-system-manager.service"
    ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
    };
    script = ''
      set -euo pipefail
      install -d -m 0755 /etc/ssh/authorized_keys.d
      if ! ${githubAuthorizedKeysScript} ${username}; then
        echo "Failed to prefill authorized keys for ${username}" >&2
        exit 1
      fi
    '';
  };

  # ------------------------------------------------------------------ #
  # Users
  # ------------------------------------------------------------------ #

  users.users."${username}" = {
    isNormalUser = true;
    home = "/home/${username}";
    shell = pkgs.zsh;
    ignoreShellProgramCheck = true;
    extraGroups = [
      "wheel"
      "docker"
    ];
  };
}
