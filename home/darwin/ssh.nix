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
#   "/Users/${username}/.bitwarden-ssh-agent.sock"
{ username, ... }:
let
  agentSocket = "/Users/${username}/Library/Containers/com.bitwarden.desktop/Data/.bitwarden-ssh-agent.sock";
in
{
  programs.ssh = {
    enable = true;
    extraConfig = ''
      IdentityAgent "${agentSocket}"
    '';
  };

  home.sessionVariables.SSH_AUTH_SOCK = agentSocket;
}
