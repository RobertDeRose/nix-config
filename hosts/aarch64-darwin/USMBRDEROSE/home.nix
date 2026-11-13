# hosts/aarch64-darwin/USMBRDEROSE/home.nix
# Per-host home-manager overrides for USMBRDEROSE (work MacBook).
# This file is imported automatically when present beside default.nix.
{ config, pkgs, ... }:
{
  home.packages = with pkgs; [ azure-cli ];

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
      # Interactive use: `ssh pool -t zsh -l`. No RemoteCommand, so scp and
      # `ssh pool <cmd>` keep working.
      "pool" = {
        HostName = "pool.checkpoint-service.com";
        User = "root";
      };
      # Not in DNS, so address it by IP.
      "arm64-github-runner" = {
        HostName = "172.174.200.195";
        User = "service";
      };
    };

    includes = [
      ''"${config.home.homeDirectory}/Library/Application Support/NVIDIA/Sync/config/ssh_config"''
    ];
  };

  # ── Personal git identity for ~/workspace/personal/ repos ───────────────
  # The conditional include is in home/common/git.nix; this just creates the file.
  home.file."workspace/personal/.gitconfig".text = ''
    [user]
        email = RobertDeRose@users.noreply.github.com
  '';
}
