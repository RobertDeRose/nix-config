# Shared mise configuration.
{
  ...
}:
{
  # Let mise request GitHub credentials only when it needs them instead of
  # exporting a token in every interactive shell.
  xdg.configFile."mise/config.toml".text = ''
    [settings.github]
    credential_command = 'gh auth token --hostname "$MISE_CREDENTIAL_HOST"'
  '';
}
