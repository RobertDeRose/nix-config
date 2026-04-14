# templates/darwin/default.nix
# Host template for a macOS machine.
# Copy this directory to hosts/aarch64-darwin/<hostname>/ to register a new Mac.
# easy-hosts sets networking.hostName automatically from the directory name.
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
}
