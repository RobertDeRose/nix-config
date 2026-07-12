# Cross-platform Git configuration deployed from native Git config files.
{
  lib,
  pkgs,
  user,
  ...
}:
let
  identity = lib.generators.toGitINI {
    user = {
      name = user.fullName;
      email = user.email;
    };
  };
  platform = lib.generators.toGitINI (
    if pkgs.stdenv.isDarwin then
      {
        core.pager = "bat -l gitlog -p";
        pager = {
          diff = "hunk pager";
          show = "hunk pager";
        };
        commit.gpgsign = true;
      }
    else
      {
        commit.gpgsign = false;
        diff.external = "${pkgs.difftastic}/bin/difft";
      }
  );
in
{
  home.activation.backupExistingGitconfig = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    legacy_config="$HOME/.gitconfig"
    if [ -e "$legacy_config" ] || [ -L "$legacy_config" ]; then
      backup_dir="$HOME/.local/state/nix-config/backups/git"
      timestamp="$(${pkgs.coreutils}/bin/date -u +%Y%m%dT%H%M%SZ)"
      mkdir -p "$backup_dir"
      backup_path="$backup_dir/gitconfig.$timestamp"
      mv "$legacy_config" "$backup_path"
      echo "Backed up legacy Git configuration to $backup_path" >&2
    fi
  '';

  home.packages = [ pkgs.git ];
  xdg.configFile."git/config".source = ../../../../dotfiles/git/config;
  xdg.configFile."git/ignore".source = ../../../../dotfiles/git/ignore;
  xdg.configFile."git/identity".text = identity;
  xdg.configFile."git/platform".text = platform;
  xdg.configFile."git/allowed_signers".text =
    "${user.email} ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMh0unYuO0QLZdrqlTx63N1NwoIpwt4BfGwQVkYbOikA\n";

  programs.difftastic = {
    enable = !pkgs.stdenv.isDarwin;
    git.enable = false;
  };
  programs.gh = {
    enable = true;
    gitCredentialHelper.enable = false;
  };
  programs.lazygit.enable = true;
}
