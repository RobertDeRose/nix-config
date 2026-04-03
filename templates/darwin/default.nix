# templates/darwin/default.nix
# Host template for a macOS machine.
# Copy this directory to hosts/aarch64-darwin/<hostname>/ to register a new Mac.
# easy-hosts sets networking.hostName automatically from the directory name.
{
  config,
  fullname,
  username,
  ...
}: {
  home-manager.users."${username}".imports =
    if builtins.pathExists ./home.nix then [ ./home.nix ] else [ ];

  networking.computerName          = config.networking.hostName;
  system.defaults.smb.NetBIOSName  = config.networking.hostName;

  users.users."${username}" = {
    home        = "/Users/${username}";
    description = fullname;
    createHome  = true;
  };

  system.primaryUser = username;
}
