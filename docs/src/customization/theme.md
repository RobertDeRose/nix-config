# Theme consistency

Static theme settings are edited in native files:

| Tool | File |
| --- | --- |
| Helix | `dotfiles/helix/config.toml` |
| Starship | `dotfiles/starship/starship.toml` |
| Starship recovery prompt | `dotfiles/starship/starship-minimal.toml` |
| Ghostty | `nix/modules/home/common/ghostty.nix` |
| Zed | `nix/modules/home/common/zed.nix` |

The default Starship prompt uses Catppuccin Macchiato. It follows the palette's semantic roles: Base for text on accent backgrounds, Text and Subtext for foreground copy, Green for success, Yellow for warnings, Red for errors, and Blue/Sapphire/Mauve/Peach for contextual segments.

System font packages remain in `nix/modules/darwin/fonts.nix`. Remote prompts are rendered by the connecting terminal, so SSH clients must select a Nerd Font locally. After changing a theme, use `maison plan` and `maison apply`; Home Manager remains the deployment owner.
