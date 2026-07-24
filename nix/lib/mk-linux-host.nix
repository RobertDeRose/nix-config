{
  inputs,
  lib,
  profileRegistry,
  systemManagerNoCheckOverlay,
  host,
}:
let
  user = host.user;
  selectedProfiles = map (name: profileRegistry.${name}) host.profiles;
  linuxModules = lib.concatMap (profile: profile.linuxModules) selectedProfiles;
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
inputs.system-manager.lib.makeSystemConfig {
  overlays = [ systemManagerNoCheckOverlay ];
  modules = [
    {
      nixpkgs.hostPlatform = host.system;
      _module.args = specialArgs;
    }
  ]
  ++ linuxModules
  ++ lib.optional (builtins.pathExists systemOverride) systemOverride;
}
