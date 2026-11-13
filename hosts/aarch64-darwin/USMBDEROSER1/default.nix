# hosts/aarch64-darwin/USMBDEROSER1/default.nix
# Host-specific config for USMBDEROSER1 (work MacBook, replaces USMBDEROSER).
#
# ── Per-host packages ────────────────────────────────────────────────────────
# These merge with the global lists in modules/darwin/apps.nix:
#   environment.systemPackages = with pkgs; [ ... ];  # nix packages (system-wide)
#   homebrew.brews = [ ... ];                         # Homebrew formulae
#   homebrew.casks = [ ... ];                         # Homebrew casks (GUI apps)
#   homebrew.masApps = { Name = appId; };             # Mac App Store apps
# For per-host user packages, add them in ./home.nix instead (see template).
{
  config,
  hmDarwinModule,
  ...
}:
let
  hostUser = import ./user.nix;
in
{
  _module.args = hostUser;
  home-manager.extraSpecialArgs = hostUser;

  home-manager.users."${hostUser.username}" = {
    imports = [
      hmDarwinModule
    ]
    ++ (if builtins.pathExists ./home.nix then [ ./home.nix ] else [ ]);
  };

  networking.computerName = config.networking.hostName;
  system.defaults.smb.NetBIOSName = config.networking.hostName;

  # ── Per-host packages ──────────────────────────────────────────────────────
  homebrew.brews = [
    "mosquitto"
  ];

  services.container-builder = {
    enable = true;
    cpus = 4;
    memory = "8G";
    # Copied from USMBDEROSER (M1 Pro, no nested virtualization), where more
    # than two NixOS VM tests at once on 4 vCPUs/8G time out. Revisit cpus,
    # memory, and maxJobs for this machine's hardware.
    maxJobs = 2;
    cli.completions.enable = true;
  };
}
