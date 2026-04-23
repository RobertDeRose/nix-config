# hosts/aarch64-darwin/USMBDEROSER/home.nix
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

  programs.ssh.matchBlocks = {
    # Add host-specific SSH aliases here.
    "dev-som" = {
      hostname = "dev-som.checkpoint-device.com";
      user = "root";
    };
  };

  # ── Personal git identity for ~/workspace/personal/ repos ───────────────
  # The conditional include is in home/common/git.nix; this just creates the file.
  home.file."workspace/personal/.gitconfig".text = ''
    [user]
        email = RobertDeRose@users.noreply.github.com
  '';
}
