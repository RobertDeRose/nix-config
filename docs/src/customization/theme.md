# Theme consistency

Static theme settings are edited in native files:

| Tool | File |
| --- | --- |
| Helix | `dotfiles/helix/config.toml` |
| Zellij | `dotfiles/zellij/config.kdl` |
| Starship | `dotfiles/starship/starship.toml` |
| Ghostty | `nix/modules/home/common/ghostty.nix` |
| Zed | `nix/modules/home/common/zed.nix` |

System font packages remain in `nix/modules/darwin/fonts.nix`. After changing a theme, use `mise run plan` and `mise run apply`; Home Manager remains the deployment owner.
