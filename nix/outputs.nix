{
  inputs,
  inventory,
  packageInventory,
}:
let
  lib = inputs.nixpkgs.lib;
  inventoryData = import ./lib/inventory.nix {
    inherit lib inventory;
  };
  profileRegistry = import ./lib/profiles.nix;
  packageData = import ./lib/packages.nix {
    inherit lib packageInventory;
  };

  darwinHosts = lib.filterAttrs (_: host: lib.hasSuffix "-darwin" host.system) inventoryData.hosts;
  linuxHosts = lib.filterAttrs (_: host: lib.hasSuffix "-linux" host.system) inventoryData.hosts;

  darwinConfigurations = lib.mapAttrs (
    _: host:
    import ./lib/mk-darwin-host.nix {
      inherit
        inputs
        lib
        profileRegistry
        packageData
        host
        ;
    }
  ) darwinHosts;

  linuxConfigurations = lib.mapAttrs (
    _: host:
    import ./lib/mk-linux-host.nix {
      inherit
        inputs
        lib
        profileRegistry
        packageData
        host
        ;
    }
  ) linuxHosts;

  systemConfigs = lib.mapAttrs (_: config: config.systemConfig) linuxConfigurations;
  homeConfigurations = lib.mapAttrs (_: config: config.homeConfig) linuxConfigurations;
in
inputs.flake-parts.lib.mkFlake { inherit inputs; } {
  systems = [
    "aarch64-darwin"
    "aarch64-linux"
    "x86_64-darwin"
    "x86_64-linux"
  ];

  flake = {
    inherit
      darwinConfigurations
      systemConfigs
      homeConfigurations
      ;
  };

  perSystem =
    { pkgs, system, ... }:
    {
      formatter = pkgs.nixfmt;
      packages =
        lib.optionalAttrs (builtins.hasAttr system inputs.system-manager.packages) {
          system-manager = inputs.system-manager.packages.${system}.default;
        }
        // lib.optionalAttrs (builtins.hasAttr system inputs.llmagents.packages) {
          opencode = inputs.llmagents.packages.${system}.opencode;
          herdr = inputs.llmagents.packages.${system}.herdr;
        }
        // lib.optionalAttrs (builtins.hasAttr system inputs.worktrunk.packages) {
          worktrunk = inputs.worktrunk.packages.${system}.worktrunk;
        };
    };
}
