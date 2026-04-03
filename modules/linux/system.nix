# modules/linux/system.nix
# Shared system-manager config for headless Ubuntu servers.
# Uses NixOS-style module options, applied via system-manager.
{
  pkgs,
  username,
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
    git
    mise
    neovim
    curl
    wget
  ];

  # ------------------------------------------------------------------ #
  # SSH
  # ------------------------------------------------------------------ #
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
    settings.PermitRootLogin = "no";
  };

  # ------------------------------------------------------------------ #
  # User
  # ------------------------------------------------------------------ #
  users.users."${username}" = {
    isNormalUser = true;
    home = "/home/${username}";
    shell = pkgs.zsh;
    ignoreShellProgramCheck = true;
    extraGroups = [ "wheel" "docker" ];
  };
}
