# Shared mise configuration.
{
  ...
}:
{
  # Let mise request GitHub credentials only when it needs them instead of
  # exporting a token in every interactive shell.
  # Keep the existing mise config managed by Maison; mise merges fragments
  # from ~/.config/mise/conf.d alongside the global config.
  xdg.configFile."mise/conf.d/github-credentials.toml".text = ''
    [settings.github]
    credential_command = 'gh auth token --hostname "$MISE_CREDENTIAL_HOST"'
  '';
}
