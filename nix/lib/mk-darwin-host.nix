{
  inputs,
  lib,
  profileRegistry,
  host,
}:
let
  user = host.user;
  selectedProfiles = map (name: profileRegistry.${name}) host.profiles;
  darwinModules = lib.concatMap (profile: profile.darwinModules) selectedProfiles;
  hostDir = ../../hosts + "/${host.name}";
  systemOverride = hostDir + "/system.nix";
  specialArgs = {
    inherit
      inputs
      host
      user
      ;
  };
in
inputs.darwin.lib.darwinSystem {
  system = host.system;
  inherit specialArgs;

  modules = [
    inputs."nix-hex-box".darwinModules.default
    inputs.nix-homebrew.darwinModules.nix-homebrew
    {
      nixpkgs.hostPlatform = host.system;
      networking.hostName = host.name;
    }
  ]
  ++ darwinModules
  ++ lib.optional (builtins.pathExists systemOverride) systemOverride;
}
