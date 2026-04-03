# home/common/ghostty.nix
# Ghostty terminal emulator — declarative config via home-manager.
# macOS only: imported from home/darwin.nix. Ghostty is installed as a
# native .app via Homebrew cask, so package = null.
{ ... }: {
  programs.ghostty = {
    enable  = true;
    package = null; # installed via Homebrew cask, not nixpkgs

    enableZshIntegration = true;

    settings = {
      theme     = "Ayu Mirage";
      font-family = "DejaVu SansM Nerd Font";
      font-size = 16;

      # Quick terminal (drop-down)
      quick-terminal-position = "top";
      quick-terminal-size     = "35%,60%";
      quick-terminal-screen   = "macos-menu-bar";

      # Shell integration
      shell-integration-features = "sudo,title,ssh-env";

      # Behaviour
      app-notifications = "clipboard-copy,config-reload";
      copy-on-select    = "clipboard";
    };
  };
}
