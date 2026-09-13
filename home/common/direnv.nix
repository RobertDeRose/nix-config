# home/common/direnv.nix
# direnv + nix-direnv + mise integration — works on macOS and Linux.
# mise itself is installed by the bootstrap script (not via nix), so we
# provide the direnv library manually to avoid pulling pkgs.mise into the
# closure. Refresh the environment on directory changes instead of spawning
# direnv after every command.
{
  lib,
  pkgs,
  ...
}:
{
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    enableZshIntegration = false;
  };

  programs.zsh.initContent = lib.mkAfter ''
    # The stock hook invokes `direnv export` before every prompt. Directory
    # changes are the normal environment boundary; explicit allow/deny/reload
    # operations refresh immediately through the wrapper below.
    _direnv_hook() {
      trap -- "" SIGINT
      eval "$(${lib.getExe pkgs.direnv} export zsh)"
      local direnv_status=$?
      trap - SIGINT
      return $direnv_status
    }
    autoload -Uz add-zsh-hook
    add-zsh-hook chpwd _direnv_hook
    _direnv_hook

    direnv() {
      ${lib.getExe pkgs.direnv} "$@"
      local direnv_status=$?
      case "''${1:-}" in
        allow|deny|reload) _direnv_hook ;;
      esac
      return $direnv_status
    }
  '';

  # Equivalent to programs.direnv.mise.enable, but uses PATH mise instead of pkgs.mise
  xdg.configFile."direnv/lib/hm-mise.sh".text = ''
    eval "$(mise direnv activate)"
  '';
}
