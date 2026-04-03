# templates/linux/home.nix
# Home-manager template for headless Ubuntu servers.
# Copy this directory to hosts/<arch>-linux/<hostname>/ to register a new host.
{ username, ... }: {
  home.homeDirectory = "/home/${username}";
}
