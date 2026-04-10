# home/common/git.nix
# Cross-platform git configuration.
{
  lib,
  pkgs,
  username,
  useremail,
  fullname,
  ...
}:
{
  # `programs.git` will generate the config file: ~/.config/git/config
  # to make git use this config file, `~/.gitconfig` should not exist!
  #    https://git-scm.com/docs/git-config#Documentation/git-config.txt---global
  home.activation.removeExistingGitconfig = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    [ -e ~/.gitconfig ] && mv -f ~/.gitconfig ~/.gitconfig.before_nix || true
  '';

  # Allowed signers file for SSH commit signature verification.
  # Maps your email to your public key so `git log --show-signature` works.
  home.file.".config/git/allowed_signers".text =
    "${useremail} ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMh0unYuO0QLZdrqlTx63N1NwoIpwt4BfGwQVkYbOikA";

  programs.difftastic.git.enable = true;

  programs.git = {
    enable = true;
    ignores = [
      ".DS_Store"
      ".jj"
    ];
    settings = {
      core = {
        autocrlf = "input";
        editor = "hx";
        whitespace = "trailing-space,space-before-tab";
        excludesfile = "~/.config/git/global_gitignore";
      };
      commit.gpgsign = pkgs.stdenv.isDarwin;
      credential.helper = "cache --timeout=3600";
      grep.lineNumber = true;
      gpg.ssh.allowedSignersFile = "~/.config/git/allowed_signers";
      init.defaultBranch = "main";
      merge.conflictstyle = "zdiff3";
      pull = {
        rebase = true;
        ff = "only";
      };
      push = {
        default = "current";
        autoSetupRemote = true;
      };
      user = {
        name = fullname;
        email = useremail;
      };
      url."git@github.com:".insteadOf = "https://github.com/";
      tar."tar.xz".command = "xz -c";
    };
    includes = [
      {
        path = "~/workspace/personal/.gitconfig";
        condition = "gitdir:~/workspace/personal/";
      }
    ];
    signing = {
      format = "ssh";
      key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMh0unYuO0QLZdrqlTx63N1NwoIpwt4BfGwQVkYbOikA";
    };
  };

  programs.gh = {
    enable = true;
    gitCredentialHelper.enable = true;
  };

  programs.lazygit.enable = true;
}
