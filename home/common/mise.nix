# Shared mise configuration.
{
  ...
}:
{
  # Let mise request GitHub credentials only when it needs them instead of
  # exporting a token in every interactive shell.
  # Keep the existing global mise config separate from Home Manager; mise
  # merges fragments from ~/.config/mise/conf.d alongside the global config.
  xdg.configFile."mise/conf.d/github-credentials.toml".text = ''
    [settings.github]
    credential_command = 'gh auth token --hostname "$MISE_CREDENTIAL_HOST"'
  '';

  # CLI tools installed by mise. Prefer this list for new CLI tools that mise
  # supports; GUI apps and tools mise can't provide go in Homebrew
  # (modules/darwin/apps.nix) or home.packages.
  xdg.configFile."mise/conf.d/tools.toml".text = ''
    [tools]
    "aqua:gastownhall/beads" = "latest" # bd
    prek = "latest"
    uv = "latest"
  '';
}
