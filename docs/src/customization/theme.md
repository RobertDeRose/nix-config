# Theme Consistency

The [Ayu Mirage](https://github.com/ayu-theme) color palette is used across all
configured tools for a consistent visual experience.

## Where Ayu Mirage Is Applied

| Tool | Config File | Theme Setting |
|------|------------|---------------|
| Ghostty | `home/common/ghostty.nix` | `theme = "ayu_mirage"` |
| Helix | `home/common/helix.nix` | `theme = "ayu_mirage"` |
| Zed | `home/common/zed.nix` | `"Ayu Mirage Dark"` |
| Zellij | `home/common/zellij.nix` | Custom Ayu Mirage theme block |
| Starship | `home/common/shell.nix` | Ayu Mirage hex colors in each segment |
| bat | via shell alias | Inherits terminal colors |

## Fonts

Font configuration lives in `modules/common/fonts.nix`:

- **DejaVu SansM Nerd Font** -- Ghostty terminal
- **MesloLGS Nerd Font** -- iTerm2, Zed editor
- **Fira Code Nerd Font** -- available as alternative
- **Symbols Only Nerd Font** -- fallback for Nerd Font glyphs

## Changing the Theme

To switch to a different color scheme:

1. Update `home/common/ghostty.nix` -- change `theme`
2. Update `home/common/helix.nix` -- change `theme`
3. Update `home/common/zed.nix` -- change the theme name in settings
4. Update `home/common/zellij.nix` -- replace the color hex values in the
   theme block
5. Update `home/common/shell.nix` -- replace the Starship segment colors
   (search for hex color codes like `#1F2430`)

All five files need to change for full consistency. The Starship prompt is
the most involved since each segment has individual foreground and background
colors.
