# hosts/aarch64-darwin/USMBDEROSER/default.nix
# Host-specific config for USMBDEROSER (work MacBook).
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

  # ── Linux builder VM (virby) ───────────────────────────────────────────────
  # Uses vfkit (Apple Virtualization.framework) — ~9s boot vs ~65s with QEMU.
  # On-demand: VM starts when nix needs a linux build, shuts down after idle.
  #
  # Manual control:
  #   Start:  sudo launchctl kickstart system/org.nix.virby
  #   Stop:   sudo launchctl kill SIGTERM system/org.nix.virby
  #   Debug:  tail -f /tmp/virbyd.log  (requires debug = true)
  #   SSH:    sudo ssh virby-vm         (or set allowUserSsh = true)
  #   Test:   nix build --impure --expr '(with import <nixpkgs> { system = "aarch64-linux"; }; hello)'
  services.virby = {
    enable = true;
    cores = 4;
    memory = "6GiB";
    onDemand = {
      enable = true;
      ttl = 5; # shut down after 5 minutes idle
    };
  };
}
