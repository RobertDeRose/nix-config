{
  host,
  pkgs,
  packageData,
  ...
}:
let
  tomlFormat = pkgs.formats.toml { };
in
{
  xdg.configFile."mise/config.toml".source = tomlFormat.generate "mise-config.toml" {
    settings.experimental = true;
    tools = packageData.miseToolsForProfiles { profiles = host.profiles; };
  };
}
