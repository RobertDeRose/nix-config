# modules/linux/system.nix
# Shared system-manager config for headless Ubuntu servers.
# Uses NixOS-style module options, applied via system-manager.
{
  lib,
  pkgs,
  username,
  githubUsername,
  hostname,
  ...
}:
let
  cache = import ../common/cache.nix;
  validUsername = builtins.match "[a-z_][a-z0-9_-]*" username != null && username != "root";
  validGithubUsername =
    builtins.match "[A-Za-z0-9]([A-Za-z0-9-]{0,37}[A-Za-z0-9])?" githubUsername != null;
  githubUsernameFile = pkgs.writeText "github-username" githubUsername;
  githubAuthorizedKeysScript = pkgs.writeShellScript "github-authorized-keys" ''
    set -euo pipefail

    requested_user="''${1:-}"
    if [ "$requested_user" != "${username}" ]; then
      exit 0
    fi

    github_username="$(${pkgs.coreutils}/bin/cat ${githubUsernameFile})"

    target_file="/etc/ssh/authorized_keys.d/${username}"
    tmp_file="$(${pkgs.coreutils}/bin/mktemp "$(dirname "$target_file")/${username}.XXXXXX")"
    trap '${pkgs.coreutils}/bin/rm -f "$tmp_file"' EXIT

    # Refresh the configured user's authorized keys from GitHub.
    if ${pkgs.curl}/bin/curl --connect-timeout 5 --max-time 10 -fsSL "https://github.com/$github_username.keys" > "$tmp_file"; then
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

  assertions = [
    {
      assertion = validUsername;
      message = "username '${username}' is not a valid managed non-root Linux username.";
    }
    {
      assertion = validGithubUsername;
      message = "githubUsername '${githubUsername}' is not a valid GitHub username.";
    }
  ];

  environment.etc."nix/nix.custom.conf" = {
    text = ''
      experimental-features = nix-command flakes
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

  environment.etc."sudoers.d/90-system-manager-wheel" = {
    text = ''
      ${username} ALL=(ALL:ALL) NOPASSWD: ALL
    '';
    mode = "0440";
    replaceExisting = true;
  };

  environment.etc."ssh/sshd_config.d/90-system-manager-authorized-keys.conf" = {
    text = ''
      AuthorizedKeysFile .ssh/authorized_keys .ssh/authorized_keys2 /etc/ssh/authorized_keys.d/%u
    '';
    mode = "0444";
    replaceExisting = true;
  };

  system-manager.preActivationAssertions.sudoersIncludeDir = {
    enable = true;
    script = ''
      if ! ${pkgs.gnugrep}/bin/grep -Eq '^[[:space:]]*[#@]includedir[[:space:]]+/etc/sudoers\.d([[:space:]]|$)' /etc/sudoers; then
        echo "Host /etc/sudoers does not include /etc/sudoers.d; refusing to replace host sudo policy." >&2
        echo "Add '#includedir /etc/sudoers.d' to /etc/sudoers before deploying this Linux config." >&2
        exit 1
      fi
    '';
  };

  system-manager.preActivationAssertions.sshdIncludeDir = {
    enable = true;
    script = ''
      if ! ${pkgs.gnugrep}/bin/grep -Eq '^[[:space:]]*Include[[:space:]]+/etc/ssh/sshd_config\.d/\*\.conf([[:space:]]|$)' /etc/ssh/sshd_config; then
        echo "Host sshd_config does not include /etc/ssh/sshd_config.d/*.conf; managed authorized keys would be ignored." >&2
        echo "Add 'Include /etc/ssh/sshd_config.d/*.conf' to /etc/ssh/sshd_config before deploying this Linux config." >&2
        exit 1
      fi
    '';
  };

  systemd.services.prefill-authorized-keys = {
    wantedBy = [ "system-manager.target" ];
    after = [
      "network-online.target"
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

      if command -v sshd >/dev/null 2>&1; then
        sshd -t
      elif [ -x /usr/sbin/sshd ]; then
        /usr/sbin/sshd -t
      else
        echo "Could not find sshd to validate configuration before restart" >&2
        exit 1
      fi

      systemctl try-restart ssh.service sshd.service 2>/dev/null || true
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
    ];
  };
}
