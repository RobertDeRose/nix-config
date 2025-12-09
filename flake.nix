{
  description = "Rob's Nix setup for macOS and Linux";

  ##################################################################################################################
  #
  # Want to know Nix in details? Looking for a beginner-friendly tutorial?
  # Check out https://github.com/ryan4yin/nixos-and-flakes-book !
  #
  ##################################################################################################################

  # the nixConfig here only affects the flake itself, not the system configuration!
  nixConfig = {
    substituters = [
      # Query the mirror of USTC first, and then the official cache.
      "https://nix-community.cachix.org"
      "https://cache.nixos.org"
    ];
    trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  # This is the standard format for flake.nix. `inputs` are the dependencies of the flake,
  # Each item in `inputs` will be passed as a parameter to the `outputs` function after being pulled and built.
  inputs = {
    # 1. Core Packages (Nixpkgs) - Pinned to the 25.11 stable release branch
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-25.11-darwin";

    # 2. Darwin System Config
    darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # 3. User Configuration
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # mac-app-util.url = "github:hraban/mac-app-util";
    # nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";
  };

  # The `outputs` function will return all the build results of the flake.
  # A flake can have many use cases and different types of outputs,
  # parameters in `outputs` are defined in `inputs` and can be referenced by their names.
  # However, `self` is an exception, this special parameter points to the `outputs` itself (self-reference)
  # The `@` syntax here is used to alias the attribute set of the inputs's parameter, making it convenient to use inside the function.
  outputs =
    inputs@{ self
    , nixpkgs
    , darwin
    , home-manager
    # , mac-app-util
    # , nix-vscode-extensions
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

        # mac-app-util.darwinModules.default

        # home manager
        home-manager.darwinModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.verbose = true;
          home-manager.extraSpecialArgs = specialArgs;
          # home-manager.sharedModules = [
          #   mac-app-util.homeManagerModules.default
          # ];
          home-manager.users.${username} = import ./home;
        }
      ];
    };

    # nix code formatter
    formatter.${system} = nixpkgs.legacyPackages.${system}.alejandra;
  };
}
