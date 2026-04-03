# modules/nixos/system.nix
# Linux-only system configuration.
# Add hardware, display-manager, desktop-environment, etc. here.
{
  pkgs,
  username,
  ...
}: {

  imports = [ ../common/fonts.nix ];

  # ------------------------------------------------------------------ #
  # Boot
  # ------------------------------------------------------------------ #
  boot.loader = {
    systemd-boot.enable      = true;
    efi.canTouchEfiVariables = true;
  };

  # ------------------------------------------------------------------ #
  # Networking
  # ------------------------------------------------------------------ #
  networking.networkmanager.enable = true;

  # ------------------------------------------------------------------ #
  # Locale / Time
  # ------------------------------------------------------------------ #
  time.timeZone      = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";

  # ------------------------------------------------------------------ #
  # Shell
  # ------------------------------------------------------------------ #
  programs.zsh.enable = true;
  environment.variables.EDITOR = "nvim";

  # ------------------------------------------------------------------ #
  # Common system packages
  # (prefer home.packages in home-manager for user-level tools)
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
  # Security
  # ------------------------------------------------------------------ #
  security.sudo.wheelNeedsPassword = true;

  # ------------------------------------------------------------------ #
  # Services
  # ------------------------------------------------------------------ #
  services.openssh = {
    enable                          = true;
    settings.PasswordAuthentication = false;
    settings.PermitRootLogin        = "no";
  };

  system.stateVersion = "25.11";
}
