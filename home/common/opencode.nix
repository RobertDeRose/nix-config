# home/common/opencode.nix
# OpenCode AI coding agent configuration.
# See https://opencode.ai/docs/config/ for available settings.
{ ... }:
{
  programs.opencode = {
    enable = true;
  };
}
