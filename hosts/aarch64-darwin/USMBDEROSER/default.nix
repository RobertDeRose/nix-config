# hosts/aarch64-darwin/USMBDEROSER/default.nix
# Host config for Robert's work MacBook.
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

  # Linux builder — aarch64-linux VM via Apple Virtualization Framework.
  # Enables building and running NixOS integration tests directly from macOS.
  # The builder VM needs enough resources to evaluate NixOS configurations
  # and build test closures (kernel, systemd, RAUC, etc.).
  nix.linux-builder = {
    enable = true;
    maxJobs = 4;
    supportedFeatures = [
      "kvm"
      "benchmark"
      "big-parallel"
      "nixos-test"
    ];
    config = {
      virtualisation = {
        cores = 6;
        darwin-builder.memorySize = 8 * 1024;
      };
    };
  };
}
