# Per-host home-manager overrides for USMBDEROSER (work MacBook).
# This file is imported automatically when present beside default.nix.
{ ... }:
{
  # ── Directory shortcuts (work-specific) ──────────────────────────────────
  home.shellAliases = {
    work = "cd ~/workspace/checkpoint";
    personal = "cd ~/workspace/personal";
    apollo = "cd ~/workspace/checkpoint/apollo";
  };

  programs.ssh = {
    enable = true;

    settings = {
      # Add host-specific SSH aliases here.
      "dev-som" = {
        HostName = "dev-som.checkpoint-device.com";
        User = "root";
      };
      "dev-ab" = {
        HostName = "dev-ab.checkpoint-device.com";
        User = "root";
      };
    };

    includes = [
      ''"/Users/DeRoseR/Library/Application Support/NVIDIA/Sync/config/ssh_config"''
    ];
  };

  # ── Personal git identity for ~/workspace/personal/ repos ───────────────
  # The conditional include is in nix/modules/home/common/git.nix; this just creates the file.
  home.file."workspace/personal/.gitconfig".text = ''
    [user]
        email = RobertDeRose@users.noreply.github.com
  '';
}
