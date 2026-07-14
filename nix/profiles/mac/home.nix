{
  inputs,
  user,
  pkgs,
  packageData,
  ...
}:
{
  home.packages =
    packageData.profileNixPackages {
      inherit pkgs;
      profile = "mac";
    }
    ++ [
      (import ../../packages/custom/llmagents.nix {
        inherit inputs pkgs;
        name = "openspec";
      })
    ];

  imports = [
    ../../modules/home/common/ghostty.nix
    ../../modules/home/common/herdr.nix
    ../../modules/home/common/opencode.nix
    ../../modules/home/common/pi.nix
    ../../modules/home/common/zed.nix
    ../../modules/home/darwin/ssh.nix
  ];

  home.homeDirectory = "/Users/${user.username}";

  fonts.fontconfig.enable = true;

  home.file = {
    "Library/Services/Open in Ghostty.workflow" = {
      source = ../../../files/workflows + "/Open in Ghostty.workflow";
      recursive = true;
    };
    "Library/Services/Open in cmux.workflow" = {
      source = ../../../files/workflows + "/Open in cmux.workflow";
      recursive = true;
    };
    "Library/Services/Open in iTerm2.workflow" = {
      source = ../../../files/workflows + "/Open in iTerm2.workflow";
      recursive = true;
    };
  };
}
