{
  pkgs,
  root,
}:
pkgs.runCommand "package-ownership-validation"
  {
    nativeBuildInputs = [ pkgs.python3 ];
  }
  ''
    export HOME="$TMPDIR"
    python3 ${root}/.mise/lib/config_edit.py --root ${root} validate
    printf '%s\n' 'packages.toml ownership validation passed' > "$out"
  ''
