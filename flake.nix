{
  description = "Rob's Nix setup for macOS and Linux";

  inputs = {
    # Core Packages — nixpkgs-unstable for latest packages
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    # Flake framework
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    # Host management (macOS only)
    easy-hosts.url = "github:tgirlcloud/easy-hosts";

    # Darwin System Config — master branch tracks nixpkgs-unstable
    darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # User Configuration — master branch tracks nixpkgs-unstable
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Declarative Homebrew installation for nix-darwin
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";

    apple-container-builder = {
      url = "github:RobertDeRose/nix-apple-container-builder";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.darwin.follows = "darwin";
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

      # Collect all Linux hosts from systems/*-linux/<hostname>/
      # Linux hosts live under systems/ (not hosts/) to avoid easy-hosts
      # auto-discovery, since easy-hosts assumes all *-linux dirs are NixOS.
      linuxHostMeta =
        let
          hostsDir = ./systems;
          allEntries = if builtins.pathExists hostsDir then builtins.readDir hostsDir else { };
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
              throw "Duplicate Linux hostname '${hostname}' found in systems/*-linux/. Hostnames must be unique across Linux architectures."
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
        let
          userNix = host.hostDir + "/user.nix";
          hostUser = if builtins.pathExists userNix then import userNix else defaultUser;
        in
        inputs.system-manager.lib.makeSystemConfig {
          modules = [
            { nixpkgs.hostPlatform = host.system; }
            ./modules/linux/system.nix
            {
              _module.args = hostUser // {
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
        let
          userNix = host.hostDir + "/user.nix";
          hostUser = if builtins.pathExists userNix then import userNix else defaultUser;
        in
        inputs.home-manager.lib.homeManagerConfiguration {
          pkgs = import inputs.nixpkgs {
            system = host.system;
            config.allowUnfree = true;
          };

          extraSpecialArgs = hostUser // {
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
        "aarch64-linux"
        "x86_64-darwin"
        "x86_64-linux"
      ];

      perSystem =
        { pkgs, system, ... }:
        {
          formatter = pkgs.nixfmt;
        }
        // lib.optionalAttrs (inputs.system-manager.packages ? ${system}) {
          packages.system-manager = inputs.system-manager.packages.${system}.default;
        };

      easy-hosts = {
        autoConstruct = true;
        path = ./hosts;

        # Linux hosts live under systems/ and are built with system-manager,
        # so easy-hosts only manages Darwin hosts from hosts/.

        shared.specialArgs = {
          hmDarwinModule = ./home/darwin.nix;
        };

        perClass = class: {
          modules =
            if class == "darwin" then
              [
                ./modules/common/nix-core.nix
                ./modules/darwin/system.nix
                ./modules/darwin/apps.nix
                ./modules/darwin/iterm2.nix

                inputs.apple-container-builder.darwinModules.default
                inputs.nix-homebrew.darwinModules.nix-homebrew
                inputs.home-manager.darwinModules.home-manager
                (
                  { pkgs, ... }:
                  {
                    home-manager.useGlobalPkgs = true;
                    home-manager.useUserPackages = true;
                    home-manager.verbose = true;
                    home-manager.backupCommand = "${pkgs.writeShellScript "hm-backup" ''
                      set -eo pipefail
                      [ $# -ge 1 ] || exit 0
                      target="$HOME/.hm_bkup/''${1#"$HOME"/}"
                      mkdir -p "$(dirname "$target")"
                      mv "$1" "$target"
                    ''}";
                    # extraSpecialArgs and users are set per-host in each
                    # host's default.nix via user.nix import.
                  }
                )
              ]
            else
              [ ];
        };
      };
    };
}
