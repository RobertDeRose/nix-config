# home/common/direnv.nix
# direnv + nix-direnv + mise integration — works on macOS and Linux.
# mise itself is installed by the bootstrap script (not via nix), so we
# provide the direnv hook manually to avoid pulling pkgs.mise into the closure.
{ ... }:
{
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    enableZshIntegration = true;
  };

  # Equivalent to programs.direnv.mise.enable, but uses PATH mise instead of pkgs.mise
  xdg.configFile."direnv/lib/hm-mise.sh".text = ''
    eval "$(mise direnv activate)"
  '';
}
