{
  lib,
  packageInventory,
}:
let
  fail = message: throw "packages.toml: ${message}";
  resolvePackage = import ./resolve-package.nix { inherit lib; };
  profiles = packageInventory.profiles or { };
  hosts = packageInventory.hosts or { };

  getAttrOr =
    name: set:
    if builtins.isAttrs set && builtins.hasAttr name set then builtins.getAttr name set else { };
  getProfile =
    name:
    if builtins.hasAttr name profiles then
      builtins.getAttr name profiles
    else
      fail "profile '${name}' has no package inventory entry";
  getProfileSection = profile: section: getAttrOr section (getProfile profile);
  getHostSection = host: section: getAttrOr section (getAttrOr host hosts);
  namesForSystem =
    section: system:
    let
      common = section.packages or [ ];
      systems = section.systems or { };
      platform = if builtins.hasAttr system systems then builtins.getAttr system systems else [ ];
    in
    common ++ platform;
  resolveNames =
    {
      pkgs,
      names,
      source,
    }:
    map (
      package:
      resolvePackage {
        inherit pkgs package;
        profile = source;
      }
    ) names;
in
if (packageInventory.schema or null) != 1 then
  fail "unsupported schema '${toString (packageInventory.schema or "missing")}'; expected schema = 1"
else
  {
    inherit packageInventory;

    profileNixPackages =
      {
        pkgs,
        profile,
      }:
      resolveNames {
        inherit pkgs;
        names = namesForSystem (getProfileSection profile "nix") pkgs.stdenv.hostPlatform.system;
        source = "profile '${profile}' Nix packages";
      };

    profileSystemPackages =
      {
        pkgs,
        profile,
      }:
      resolveNames {
        inherit pkgs;
        names = namesForSystem (getProfileSection profile "system") pkgs.stdenv.hostPlatform.system;
        source = "profile '${profile}' system packages";
      };

    hostNixPackages =
      {
        pkgs,
        host,
      }:
      resolveNames {
        inherit pkgs;
        names = namesForSystem (getHostSection host "nix") pkgs.stdenv.hostPlatform.system;
        source = "host '${host}' Nix packages";
      };

    profileHomebrew =
      {
        profile,
        system,
      }:
      let
        section = getProfileSection profile "homebrew";
        systems = section.systems or { };
        platformCasks = if builtins.hasAttr system systems then builtins.getAttr system systems else [ ];
      in
      {
        taps = section.taps or [ ];
        brews = section.brews or [ ];
        casks = (section.casks or [ ]) ++ platformCasks;
      };

    hostHomebrew =
      { host }:
      let
        section = getHostSection host "homebrew";
      in
      {
        taps = section.taps or [ ];
        brews = section.brews or [ ];
        casks = section.casks or [ ];
      };

    profileMas = { profile }: getProfileSection profile "mas";
  }
