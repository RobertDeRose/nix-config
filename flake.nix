{
  description = "Rob's Nix setup for macOS and Linux";

  nixConfig = {
    extra-substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
    ];
    extra-trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
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

    # Provide a default pin for system-manager so all evaluators
    # use lockfile revisions instead of GitHub HEAD lookups.
    system-manager = {
      url = "github:numtide/system-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # System Manager for non-NixOS Linux (Ubuntu)
    # (Kept above intentionally so it is always represented in flake.lock.)
  };

  outputs =
    inputs:
    let
      lib = inputs.nixpkgs.lib;
      defaultUser = {
        fullname = "Robert DeRose";
        username = "rderose";
        useremail = "rderose@checkpt.com";
        githubUsername = "RobertDeRose";
      };

      # Collect all Linux hosts from hosts/*-linux/<hostname>/
      linuxHostMeta =
        let
          hostsDir = ./hosts;
          allEntries = builtins.readDir hostsDir;
          linuxArchDirs = lib.filterAttrs (
            name: type: lib.hasSuffix "-linux" name && type == "directory"
          ) allEntries;
        in
        lib.foldlAttrs (
          acc: archName: _:
          let
            archDir = hostsDir + "/${archName}";
            archEntries = builtins.readDir archDir;
            hostNames = lib.filterAttrs (_: type: type == "directory") archEntries;
          in
          lib.foldlAttrs (
            acc: hostname: _:
            let
              hostDir = archDir + "/${hostname}";
              system = if lib.hasPrefix "x86_64" archName then "x86_64-linux" else "aarch64-linux";
            in
            if acc ? "${hostname}" then
              throw "Duplicate Linux hostname '${hostname}' found in hosts/*-linux/. Hostnames must be unique across Linux architectures."
            else
              acc
              // {
                "${hostname}" = {
                  inherit hostname hostDir system;
                };
              }
          ) acc hostNames
        ) { } linuxArchDirs;

      linuxHosts = lib.mapAttrs (
        _: host:
        inputs.system-manager.lib.makeSystemConfig {
          modules = [
            { nixpkgs.hostPlatform = host.system; }
            ./modules/linux/system.nix
            {
              _module.args = defaultUser // {
                inherit (host) hostname;
              };
            }
          ]
          ++ (
            let
              systemNix = host.hostDir + "/system.nix";
            in
            if builtins.pathExists systemNix then [ { imports = [ systemNix ]; } ] else [ ]
          );
        }
      ) linuxHostMeta;

      linuxHomeConfigs = lib.mapAttrs (
        hostname: host:
        inputs.home-manager.lib.homeManagerConfiguration {
          pkgs = import inputs.nixpkgs {
            system = host.system;
            config.allowUnfree = true;
          };

          extraSpecialArgs = defaultUser // {
            inherit hostname;
          };

          modules = [
            ./home/linux.nix
          ]
          ++ (
            let
              homeNix = host.hostDir + "/home.nix";
            in
            if builtins.pathExists homeNix then [ homeNix ] else [ ]
          );
        }
      ) linuxHostMeta;
    in
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        inputs.easy-hosts.flakeModule
        inputs.flake-parts.flakeModules.easyOverlay
      ];

      flake.systemConfigs = linuxHosts;
      flake.homeConfigurations = linuxHomeConfigs;

      systems = [
        "aarch64-darwin"
        "x86_64-darwin"
        "x86_64-linux"
      ];

      perSystem =
        { pkgs, ... }:
        {
          formatter = pkgs.nixfmt;
        };

      easy-hosts = {
        autoConstruct = true;
        path = ./hosts;

        # Auto-discovered Linux hosts come through as class = "linux"
        # from the <arch>-linux directory name, so map that alias to nixos.
        additionalClasses = {
          linux = "nixos";
        };

        shared.specialArgs = defaultUser;

        perClass = class: {
          modules =
            if class == "darwin" then
              [
                ./modules/common/nix-core.nix
                ./modules/darwin/system.nix
                ./modules/darwin/apps.nix
                ./modules/darwin/iterm2.nix

                inputs.home-manager.darwinModules.home-manager
                {
                  home-manager.useGlobalPkgs = true;
                  home-manager.useUserPackages = true;
                  home-manager.verbose = true;
                  home-manager.backupCommand = ''
                    target="$HOME/.hm_bkup/$(realpath --relative-to="$HOME" "$1")"
                    mkdir -p "$(dirname "$target")"
                    mv "$1" "$target"
                  '';
                  home-manager.extraSpecialArgs = defaultUser;
                  home-manager.users.${defaultUser.username} = import ./home/darwin.nix;
                }
              ]
            else
              [ ];
        };
      };
    };
}
