# Cross-platform CLI tools and programs.
{
  pkgs,
  inputs,
  packageData,
  ...
}:
let
  customAgent =
    name:
    import ../../../packages/custom/llmagents.nix {
      inherit inputs pkgs name;
    };
in
{
  home.packages =
    packageData.profileNixPackages {
      inherit pkgs;
      profile = "base";
    }
    ++ [ (customAgent "openspec") ];

  programs = {
    fzf = {
      enable = true;
      enableZshIntegration = true;
    };

    eza = {
      enable = true;
      git = true;
      icons = "auto";
      enableZshIntegration = true;
    };

    yazi = {
      enable = true;
      enableZshIntegration = true;
      shellWrapperName = "y";
      settings.manager = {
        show_hidden = true;
        sort_dir_first = true;
      };
    };
  };

  home.sessionVariables = {
    VISUAL = "hx";
    EDITOR = "hx";
    GIT_EDITOR = "hx";
    GIT_SEQUENCE_EDITOR = "hx";
  };

  home.file.".local/bin/rund" = {
    source = ../../../../files/scripts/rund;
    executable = true;
  };
}
