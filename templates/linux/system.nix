# templates/linux/system.nix
# System-manager template for headless Ubuntu servers.
# Copy this directory to systems/<arch>-linux/<hostname>/ to register a new host.
#
# ── Per-host packages ────────────────────────────────────────────────────────
# These merge with the global list in modules/linux/system.nix:
#   environment.systemPackages = with pkgs; [ ... ];
# For per-host user packages, add them in ./home.nix instead (see template).
{ pkgs, ... }:
{
}
