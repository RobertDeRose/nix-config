# home/common/ssh.nix
# macOS SSH client config with Bitwarden SSH agent integration.
#
# Bitwarden Desktop (Mac App Store) acts as an SSH agent — keys are
# stored in the vault and unlocked via biometrics.
#
# The Mac App Store version uses a sandboxed container socket path:
#   ~/Library/Containers/com.bitwarden.desktop/Data/.bitwarden-ssh-agent.sock
#
# If you switch to the .dmg install, change agentSocket to:
#   "/Users/${username}/.bitwarden-ssh-agent.sock"
{ username, ... }:
let
  agentSocket = "/Users/${username}/Library/Containers/com.bitwarden.desktop/Data/.bitwarden-ssh-agent.sock";
in
{
  programs.ssh = {
    enable = true;

    # Route all SSH connections through the Bitwarden SSH agent.
    extraConfig = ''
      IdentityAgent "${agentSocket}"
    '';
  };

  # Point SSH_AUTH_SOCK at Bitwarden's agent so all SSH clients
  # (git, scp, ssh, etc.) use it automatically.
  home.sessionVariables.SSH_AUTH_SOCK = agentSocket;
}
