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
  linuxModules = lib.concatMap (profile: profile.linuxModules) selectedProfiles;
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
{
  systemConfig = inputs.system-manager.lib.makeSystemConfig {
    modules = [
      {
        nixpkgs.hostPlatform = host.system;
        _module.args = specialArgs;
      }
    ]
    ++ linuxModules
    ++ lib.optional (builtins.pathExists systemOverride) systemOverride;
  };

  homeConfig = inputs.home-manager.lib.homeManagerConfiguration {
    pkgs = import inputs.nixpkgs {
      system = host.system;
      config.allowUnfree = true;
    };
    extraSpecialArgs = specialArgs;
    modules = homeModules ++ lib.optional (builtins.pathExists homeOverride) homeOverride;
  };
}
