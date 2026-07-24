{
  inputs,
  inventory,
}:
let
  lib = inputs.nixpkgs.lib;
  inventoryData = import ./lib/inventory.nix {
    inherit lib inventory;
  };
  profileRegistry = import ./lib/profiles.nix;
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
        host
        ;
    }
  ) darwinHosts;

  systemConfigs = lib.mapAttrs (
    _: host:
    import ./lib/mk-linux-host.nix {
      inherit
        inputs
        lib
        profileRegistry
        systemManagerNoCheckOverlay
        host
        ;
    }
  ) linuxHosts;

  deploy = import ./lib/deployments.nix {
    inherit
      inputs
      lib
      inventoryData
      systemConfigs
      ;
  };
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
      deploy
      ;
  };

  perSystem =
    { pkgs, system, ... }:
    let
      hasSystemManager = builtins.hasAttr system inputs.system-manager.packages;
      systemManagerPackage =
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
    in
    {
      formatter = pkgs.nixfmt-tree;

      packages = {
        inherit (pkgs) nh deploy-rs;
      }
      // lib.optionalAttrs hasSystemManager {
        system-manager = systemManagerPackage;
      };

      apps = {
        deploy = {
          type = "app";
          program = "${pkgs.deploy-rs}/bin/deploy";
        };
        nh = {
          type = "app";
          program = "${pkgs.nh}/bin/nh";
        };
      }
      // lib.optionalAttrs hasSystemManager {
        system-manager = {
          type = "app";
          program = "${systemManagerPackage}/bin/system-manager";
        };
      };

      checks = {
        inventory = import ./checks/inventory.nix {
          inherit pkgs inventoryData;
        };
      }
      // import ./checks/hosts.nix {
        inherit
          lib
          system
          inventoryData
          darwinConfigurations
          systemConfigs
          ;
      }
      // lib.optionalAttrs (builtins.hasAttr system inputs.deploy-rs.lib) (
        inputs.deploy-rs.lib.${system}.deployChecks deploy
      );
    };
}
