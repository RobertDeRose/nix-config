{
  base = {
    darwinModules = [ ../profiles/base/darwin.nix ];
    linuxModules = [ ../profiles/base/linux.nix ];
    homeModules = [ ../profiles/base/home.nix ];
  };

  developer = {
    darwinModules = [ ];
    linuxModules = [ ];
    homeModules = [ ../profiles/developer/home.nix ];
  };

  mac-desktop = {
    darwinModules = [ ../profiles/mac-desktop/system.nix ];
    linuxModules = [ ];
    homeModules = [ ../profiles/mac-desktop/home.nix ];
  };

  linux-server = {
    darwinModules = [ ];
    linuxModules = [ ../profiles/linux-server/system.nix ];
    homeModules = [ ../profiles/linux-server/home.nix ];
  };
}
