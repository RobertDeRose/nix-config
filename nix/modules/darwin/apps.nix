# macOS package and application ownership.
{
  pkgs,
  lib,
  user,
  host,
  packageData,
  ...
}:
let
  profileBrew = packageData.profileHomebrew {
    profile = "mac-desktop";
    system = host.system;
  };
  hostBrew = packageData.hostHomebrew { host = host.name; };
  taps = lib.unique (profileBrew.taps ++ hostBrew.taps);
  brews = lib.unique (profileBrew.brews ++ hostBrew.brews);
  casks = lib.unique (profileBrew.casks ++ hostBrew.casks);
in
{
  environment.systemPackages = packageData.profileSystemPackages {
    inherit pkgs;
    profile = "mac-desktop";
  };

  nix-homebrew = {
    enable = true;
    user = user.username;
    autoMigrate = true;
    extraEnv.HOMEBREW_NO_ENV_HINTS = "1";
  };

  homebrew = {
    enable = true;

    onActivation = {
      autoUpdate = false;
      upgrade = false;
      cleanup = "none";
    };

    taps = map (name: {
      inherit name;
      trusted = true;
    }) taps;

    inherit brews casks;
    masApps = packageData.profileMas { profile = "mac-desktop"; };
  };
}
