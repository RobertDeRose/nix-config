{
  base = {
    darwinModules = [ ../profiles/base/darwin.nix ];
    linuxModules = [ ../profiles/base/linux.nix ];
    homeModules = [ ../profiles/base/home.nix ];
  };

  dev = {
    darwinModules = [ ];
    linuxModules = [ ];
    homeModules = [ ../profiles/dev/home.nix ];
  };

  mac = {
    darwinModules = [ ../profiles/mac/system.nix ];
    linuxModules = [ ];
    homeModules = [ ../profiles/mac/home.nix ];
  };

  linux = {
    darwinModules = [ ];
    linuxModules = [ ../profiles/linux/system.nix ];
    homeModules = [ ../profiles/linux/home.nix ];
  };
}
