{
  description = "Rob's Nix setup for macOS and Linux";

  # This is the standard format for flake.nix. `inputs` are the dependencies of the flake, Each item in `inputs` will be
  # passed as a parameter to the `outputs` function after being pulled and built.
  inputs = {
    # Core Packages (Nixpkgs) - Pinned to the 25.11 stable release branch
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-25.11-darwin";

    # Darwin System Config
    darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Support Login Items
    darwin-login-items.url = "github:uncenter/nix-darwin-login-items";

    # User Configuration
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Flake Module management
    flake-parts {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    # GitOps for NixOS and nix-darwin
    comin = {
      url = "github:nlewo/comin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Easily configure hosts
    easy-hosts.url = "github:tgirlcloud/easy-hosts";

    # Install homebrew if not installed
    homebrew = "github:zhaofengli/nix-homebrew";

    # Transative deps
    systems = "github:nix-systems/default-darwin";

    # Formatter
    treefmt-nix.url = "github:numtide/treefmt-nix";
  };

  # The `outputs` function will return all the build results of the flake. A flake can have many use cases and different
  # types of outputs, parameters in `outputs` are defined in `inputs` and can be referenced by their names. However,
  # `self` is an exception, this special parameter points to the `outputs` itself (self-reference) The `@` syntax here
  # is used to alias the attribute set of the inputs's parameter, making it convenient to use inside the function.
  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      inherit (inputs) systems;

      imports = [
        inputs.easy-hosts.flakeModule
        inputs.treefmt-nix.flakeModule
        inputs.home-manager.flakeModules.home-manager
      ];

      perSystem = { config, self', inputs', pkgs, system, ... }: {
        # Per-system attributes can be defined here. The self' and inputs'
        # module parameters provide easy access to attributes of the same
        # system.
        treefmt = {
          programs.nixfmt.enable = pkgs.lib.meta.availableOn pkgs.stdenv.buildPlatform pkgs.nixfmt-rfc-style.compiler;
          programs.nixfmt.package = pkgs.nixfmt-rfc-style;
          programs.shellcheck.enable = true;
          settings.formatter.shellcheck.options = [
            "-s"
            "bash"
          ];
        };
      };

      easy-hosts = {
        path = ./hosts;

        shared = {
          modules = [ ./modules/base ];
          specialArgs = { inherit inputs; };
        };

        perClass = class: {
          modules = [ ./modules/${class}/default.nix ];
        };

        hosts = {
          USMBDEROSER = {
            arch = "aarch64";
            class = "darwin";
            tags = [ "laptop" ];
          };

          dev-som = {
            arch = "aarch64";
            class = "nixos";
            tags = [ "server" ];
          };

          jammy = {
            arch = "aarch64";
            class = "nixos";
            tags = [ "vm" ];
          };
        };
      };

      flake = {
        # The usual flake attributes can be defined here, including system-
        # agnostic ones like nixosModule and system-enumerating ones, although
        # those are more easily expressed in perSystem.

      };
    };
};
  outputs =
    inputs@{ self
    , nixpkgs
    , darwin
    , home-manager
    # , mac-app-util , nix-vscode-extensions
    , ...
  }: let
    fullname = "Robert DeRose";
    hostname = "<<HOSTNAME>>";
    username = "rderose";
    useremail = "rderose@checkpt.com";
    system = "aarch64-darwin"; # aarch64-darwin or x86_64-darwin

    specialArgs =
      inputs
      // {
        inherit fullname hostname username useremail;
      };
  in {
    darwinConfigurations."${hostname}" = darwin.lib.darwinSystem {
      inherit system specialArgs;
      modules = [
        ./modules/nix-core.nix
        ./modules/system.nix
        ./modules/apps.nix
        ./modules/host-users.nix

        # home manager
        home-manager.darwinModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.verbose = true;
          home-manager.extraSpecialArgs = specialArgs;
          # home-manager.sharedModules = [ mac-app-util.homeManagerModules.default
          # ];
          home-manager.users.${username} = import ./home;
        }
      ];
    };

    # nix code formatter
    formatter.${system} = nixpkgs.legacyPackages.${system}.alejandra;
  };
}
