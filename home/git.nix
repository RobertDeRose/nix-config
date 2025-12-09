{
  lib,
  username,
  useremail,
  fullname,
  ...
}: {
  # `programs.git` will generate the config file: ~/.config/git/config
  # to make git use this config file, `~/.gitconfig` should not exist!
  #
  #    https://git-scm.com/docs/git-config#Documentation/git-config.txt---global
  home.activation.removeExistingGitconfig = lib.hm.dag.entryBefore ["checkLinkTargets"] ''
    [ -e ~/.gitconfig ] && mv -f ~/.gitconfig ~/.gitcofig.before_nix
  '';

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
        editor = "nvim";
        whitespace = "trailing-space,space-before-tab";
        excludesfile = "~/.config/git/global_gitignore";
      };
      commit.gpgsign = true;
      credential.helper = "cache --timeout=3600";
      grep.lineNumber = true;
      gpg.ssh.allowedSignersFile = "~/.config/git/allowed_signers";
      includes = {
        path = "~/workspace/personal/.gitconfig";
        condition = "gitdir:~/workspace/personal/";
      };
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
      url = {
        "git@github.com:" = {
          insteadOf = "https://github.com/";
        };
      };
      safe.directory = "*";
      tar."tar.xz" = {
        command = "xz -c";
      };
    };
    signing = {
      format = "ssh";
      # signingkey = "";
    };
  };

  programs.gh = {
    enable = true;
    gitCredentialHelper.enable = true;
  };

  programs.lazygit.enable = true;
}
