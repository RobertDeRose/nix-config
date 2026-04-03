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

    # Host management (macOS only)
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

    # System Manager for non-NixOS Linux (Ubuntu)
    system-manager = {
      url = "github:numtide/system-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs:
    let
      lib = inputs.nixpkgs.lib;
      defaultUser = {
        fullname  = "Robert DeRose";
        username  = "rderose";
        useremail = "rderose@checkpt.com";
      };

      # Collect all linux hosts from hosts/*-linux/<hostname>/
      linuxHosts = let
        hostsDir = ./hosts;
        allEntries = builtins.readDir hostsDir;
        linuxArchDirs = lib.filterAttrs (name: type:
          lib.hasSuffix "-linux" name && type == "directory"
        ) allEntries;
      in
        lib.foldlAttrs (acc: archName: _:
          let
            archDir = hostsDir + "/${archName}";
            archEntries = builtins.readDir archDir;
            hostNames = lib.filterAttrs (_: type: type == "directory") archEntries;
          in
            lib.foldlAttrs (acc: hostname: _:
              let
                hostDir = archDir + "/${hostname}";
                system =
                  if lib.hasPrefix "x86_64" archName
                  then "x86_64-linux"
                  else "aarch64-linux";
              in
                acc // {
                  "${hostname}" = inputs.system-manager.lib.makeSystemConfig {
                    modules = [
                      { nixpkgs.hostPlatform = system; }
                      ./modules/linux/system.nix
                      {
                        _module.args = { inherit hostname; };
                        _module.specialArgs = defaultUser;
                      }
                    ] ++ (
                      let systemNix = hostDir + "/system.nix";
                      in if builtins.pathExists systemNix
                        then [ { imports = [ systemNix ]; } ]
                        else []
                    );
                  };
                }
            ) acc hostNames
        ) {} linuxArchDirs;
    in
      inputs.flake-parts.lib.mkFlake { inherit inputs; } {
        imports = [ inputs.easy-hosts.flakeModule ];

        systems = [
          "aarch64-darwin"
          "x86_64-darwin"
          "x86_64-linux"
        ];

        perSystem = { pkgs, ... }: {
          formatter = pkgs.alejandra;
        };

        easy-hosts = {
          autoConstruct = true;
          path = ./hosts;

          shared.specialArgs = defaultUser;

          perClass = class: {
            modules =
              if class == "darwin" then [
                ./modules/common/nix-core.nix
                ./modules/darwin/system.nix
                ./modules/darwin/apps.nix
                ./modules/darwin/iterm2.nix

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
              else [];
          };
        };

        systemConfigs = linuxHosts;
      };
}
