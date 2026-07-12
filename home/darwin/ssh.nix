# home/darwin/ssh.nix
# macOS SSH client config with Bitwarden SSH agent integration.
#
# Bitwarden Desktop (Mac App Store) acts as an SSH agent — keys are
# stored in the vault and unlocked via biometrics.
#
# The Mac App Store version uses a sandboxed container socket path:
#   ~/Library/Containers/com.bitwarden.desktop/Data/.bitwarden-ssh-agent.sock
#
# If you switch to the .dmg install, change agentSocket below to:
#   "/Users/${user.username}/.bitwarden-ssh-agent.sock"
{ user, ... }:
let
  agentSocket = "/Users/${user.username}/Library/Containers/com.bitwarden.desktop/Data/.bitwarden-ssh-agent.sock";
in
{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings."*" = {
      IdentityAgent = ''"${agentSocket}"'';
    };
  };

  home.sessionVariables.SSH_AUTH_SOCK = agentSocket;
}
