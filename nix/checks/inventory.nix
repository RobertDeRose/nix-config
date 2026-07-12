{
  pkgs,
  inventoryData,
}:
let
  validated = builtins.deepSeq inventoryData true;
in
assert validated;
pkgs.runCommandNoCC "inventory-validation" { } ''
  printf '%s\n' 'inventory.toml evaluated successfully' > "$out"
''
