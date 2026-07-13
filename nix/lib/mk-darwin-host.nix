{
  inputs,
  lib,
  profileRegistry,
  packageData,
  host,
}:
let
  user = host.user;
  selectedProfiles = map (name: profileRegistry.${name}) host.profiles;
  darwinModules = lib.concatMap (profile: profile.darwinModules) selectedProfiles;
  homeModules = lib.concatMap (profile: profile.homeModules) selectedProfiles;
  hostDir = ../../hosts + "/${host.name}";
  systemOverride = hostDir + "/system.nix";
  homeOverride = hostDir + "/home.nix";
  specialArgs = {
    inherit
      inputs
      host
      user
      packageData
      ;
  };
in
inputs.darwin.lib.darwinSystem {
  system = host.system;
  inherit specialArgs;

  modules = [
    inputs."nix-hex-box".darwinModules.default
    inputs.nix-homebrew.darwinModules.nix-homebrew
    inputs.home-manager.darwinModules.home-manager
    {
      nixpkgs.hostPlatform = host.system;
      networking.hostName = host.name;
    }
    (
      { pkgs, ... }:
      {
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.verbose = true;
        home-manager.extraSpecialArgs = specialArgs;
        home-manager.backupCommand = "${pkgs.writeShellScript "hm-backup" ''
          set -euo pipefail
          [ "$#" -ge 1 ] || exit 0
          target="$HOME/.hm_bkup/''${1#"$HOME"/}"
          mkdir -p "$(dirname "$target")"
          mv "$1" "$target"
          echo "Backed up Home Manager conflict to $target" >&2
        ''}";
        home-manager.users.${user.username}.imports =
          homeModules ++ lib.optional (builtins.pathExists homeOverride) homeOverride;
      }
    )
  ]
  ++ darwinModules
  ++ lib.optional (builtins.pathExists systemOverride) systemOverride;
}
