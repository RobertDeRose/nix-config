{ lib }:
final: prev: {
  rustPlatform = prev.rustPlatform // {
    buildRustPackage =
      args:
      prev.rustPlatform.buildRustPackage (
        if builtins.isFunction args then
          finalAttrs:
          let
            resolved = args finalAttrs;
          in
          resolved
          // lib.optionalAttrs ((resolved.pname or "") == "system-manager") {
            doCheck = false;
          }
        else
          args
          // lib.optionalAttrs ((args.pname or "") == "system-manager") {
            doCheck = false;
          }
      );
  };
}
