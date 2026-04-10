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
