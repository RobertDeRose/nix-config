{ lib }:
let
  supportedSystems = [
    "aarch64-darwin"
    "x86_64-darwin"
    "aarch64-linux"
    "x86_64-linux"
  ];
  profileNames = [
    "base"
    "dev"
    "mac"
    "linux"
  ];
  validHostname = value: builtins.match "[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?" value != null;
  validUsername = value: value != "root" && builtins.match "[a-z_][a-z0-9_-]*" value != null;
  validGithub = value: builtins.match "[A-Za-z0-9]([A-Za-z0-9-]{0,37}[A-Za-z0-9])?" value != null;
  compatibleProfile =
    system: profile:
    if profile == "mac" then
      lib.hasSuffix "-darwin" system
    else if profile == "linux" then
      lib.hasSuffix "-linux" system
    else
      true;
in
{
  inherit
    supportedSystems
    profileNames
    validHostname
    validUsername
    validGithub
    compatibleProfile
    ;
}
