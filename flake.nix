{
  description = "Rob's Nix setup for macOS and Linux";

  nixConfig = {
    substituters = [
      "https://nix-community.cachix.org"
      "https://cache.nixos.org"
    ];
    trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  inputs = {
    # Core Packages - pinned to 25.11 stable
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";

    # Flake framework
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    # Host management
    easy-hosts.url = "github:tgirlcloud/easy-hosts";

    # Darwin System Config
    darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # User Configuration
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Hardware-optimised configs for Linux machines
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ inputs.easy-hosts.flakeModule ];

      # ------------------------------------------------------------------ #
      # Systems for perSystem outputs (formatter, etc.)
      # ------------------------------------------------------------------ #
      systems = [
        "aarch64-darwin"
        "x86_64-darwin"
        "x86_64-linux"
      ];

      # ------------------------------------------------------------------ #
      # Per-system outputs
      # ------------------------------------------------------------------ #
      perSystem = { pkgs, ... }: {
        formatter = pkgs.alejandra;
      };

      # ------------------------------------------------------------------ #
      # Host configuration — auto-discovered from hosts/<arch>-<class>/<hostname>/
      #
      # To add a new host, run:  mise run nix:add-host <hostname> [system]
      # This creates the directory; no flake.nix editing required.
      # ------------------------------------------------------------------ #
      easy-hosts = let
        defaultUser = {
          fullname  = "Robert DeRose";
          username  = "rderose";
          useremail = "rderose@checkpt.com";
        };
      in {
        autoConstruct = true;
        path = ./hosts;

        shared.specialArgs = defaultUser;

        perClass = class: {
          modules =
            if class == "darwin" then [
              ./modules/common/nix-core.nix
              ./modules/darwin/system.nix
              ./modules/darwin/apps.nix

              inputs.home-manager.darwinModules.home-manager
              {
                home-manager.useGlobalPkgs       = true;
                home-manager.useUserPackages     = true;
                home-manager.verbose             = true;
                home-manager.backupFileExtension = "bak";
                home-manager.extraSpecialArgs    = defaultUser;
                home-manager.users.${defaultUser.username} = import ./home/darwin.nix;
              }
            ]
            else if class == "nixos" then [
              ./modules/common/nix-core.nix
              ./modules/nixos/system.nix

              inputs.home-manager.nixosModules.home-manager
              {
                home-manager.useGlobalPkgs       = true;
                home-manager.useUserPackages     = true;
                home-manager.verbose             = true;
                home-manager.backupFileExtension = "bak";
                home-manager.extraSpecialArgs    = defaultUser;
                home-manager.users.${defaultUser.username} = import ./home/linux.nix;
              }
            ]
            else [];
        };
      };
    };
}
