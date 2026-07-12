{
  inputs,
  pkgs,
  name,
}:
let
  system = pkgs.stdenv.hostPlatform.system;
  packages =
    if builtins.hasAttr system inputs.llmagents.packages then
      inputs.llmagents.packages.${system}
    else
      throw "llmagents package set is unavailable for ${system}";
in
if builtins.hasAttr name packages then
  packages.${name}
else
  throw "llmagents custom package '${name}' is unavailable for ${system}"
