# home/common/direnv.nix
# direnv + nix-direnv + mise integration — works on macOS and Linux.
{ ... }: {
  programs.direnv = {
    enable               = true;
    nix-direnv.enable    = true;
    enableZshIntegration = true;
    mise.enable          = true;
  };
}
