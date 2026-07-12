{ lib }:
{
  pkgs,
  package,
  profile,
  system ? pkgs.stdenv.hostPlatform.system,
}:
let
  segments = lib.splitString "." package;
  resolved = lib.foldl' (
    state: segment:
    if state.found && builtins.isAttrs state.value && builtins.hasAttr segment state.value then
      {
        found = true;
        value = builtins.getAttr segment state.value;
      }
    else
      {
        found = false;
        value = null;
      }
  )
    {
      found = true;
      value = pkgs;
    }
    segments;
in
if !resolved.found then
  throw ''
    Package "${package}" in ${profile} is not available on ${system}.
    Invalid nixpkgs attribute path: ${package}
    Search explicitly with: mise run package:search ${package}
  ''
else if !lib.isDerivation resolved.value then
  throw ''
    Package "${package}" in ${profile} resolves to a non-package value on ${system}.
    Expected a nixpkgs derivation at attribute path: ${package}
    Search explicitly with: mise run package:search ${package}
  ''
else
  resolved.value
