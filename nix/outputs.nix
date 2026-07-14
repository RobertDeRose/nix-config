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
  systemManagerNoCheckOverlay = import ./lib/system-manager-no-check-overlay.nix { inherit lib; };

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
        systemManagerNoCheckOverlay
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
      formatter = pkgs.nixfmt-tree;
      packages =
        lib.optionalAttrs (builtins.hasAttr system inputs.system-manager.packages) {
          system-manager =
            let
              systemManagerPkgs = import inputs.nixpkgs {
                inherit system;
                overlays = [
                  systemManagerNoCheckOverlay
                  inputs.system-manager.overlays.default
                ];
              };
            in
            systemManagerPkgs.system-manager;
        }
        //
          lib.optionalAttrs
            (lib.hasSuffix "-darwin" system && builtins.hasAttr system inputs.llmagents.packages)
            {
              herdr = inputs.llmagents.packages.${system}.herdr;
              opencode = inputs.llmagents.packages.${system}.opencode;
              openspec = inputs.llmagents.packages.${system}.openspec;
              pi = inputs.llmagents.packages.${system}.pi;
            };

      checks = {
        inventory = import ./checks/inventory.nix {
          inherit pkgs inventoryData;
        };
        package-ownership = import ./checks/package-ownership.nix {
          inherit pkgs;
          root = ../.;
        };
      }
      // import ./checks/hosts.nix {
        inherit
          lib
          system
          inventoryData
          darwinConfigurations
          systemConfigs
          homeConfigurations
          ;
      };
    };
}
