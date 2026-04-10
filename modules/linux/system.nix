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
{
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
        set -euo pipefail

        requested_user="''${1:-}"
        if [ "$requested_user" != "${username}" ]; then
          exit 0
        fi

        cache_dir="/var/cache/ssh-authorized-keys"
        cache_file="$cache_dir/${username}.keys"
        tmp_file="$cache_file.tmp"
        cache_ttl_seconds=3600
        now="$(${pkgs.coreutils}/bin/date +%s)"

        ${pkgs.coreutils}/bin/mkdir -p "$cache_dir"

        # Serve from cache if fresh
        if [ -s "$cache_file" ]; then
          cache_mtime="$(${pkgs.coreutils}/bin/date -r "$cache_file" +%s)"
          cache_age=$((now - cache_mtime))
          if [ "$cache_age" -lt "$cache_ttl_seconds" ]; then
            exec ${pkgs.coreutils}/bin/cat "$cache_file"
          fi
        fi

        # Try to refresh from GitHub
        if ${pkgs.curl}/bin/curl --connect-timeout 5 --max-time 10 -fsSL "https://github.com/${githubUsername}.keys" > "$tmp_file"; then
          ${pkgs.coreutils}/bin/mv "$tmp_file" "$cache_file"
          exec ${pkgs.coreutils}/bin/cat "$cache_file"
        fi

        ${pkgs.coreutils}/bin/rm -f "$tmp_file"

        # Fall back to stale cache if fetch failed
        if [ -s "$cache_file" ]; then
          exec ${pkgs.coreutils}/bin/cat "$cache_file"
        fi

        exit 1
      ''} %u";
      AuthorizedKeysCommandUser = "_sshkeys";
    };
  };

  systemd.tmpfiles.rules = [
    "d /var/cache/ssh-authorized-keys 0750 _sshkeys nogroup - -"
  ];

  # ------------------------------------------------------------------ #
  # Users
  # ------------------------------------------------------------------ #

  # Unprivileged user for AuthorizedKeysCommand (least-privilege)
  users.users."_sshkeys" = {
    isSystemUser = true;
    group = "nogroup";
    home = "/nonexistent";
    shell = "/usr/sbin/nologin";
  };

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
