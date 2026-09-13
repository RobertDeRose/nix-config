# Theme Consistency

The [Ayu Mirage](https://github.com/ayu-theme) color palette is used across all
configured tools by default. Starship can instead use either copied Maison theme
without changing the other tool themes.

## Where Ayu Mirage Is Applied

| Tool | Config File | Theme Setting |
|------|------------|---------------|
| Ghostty | `home/common/ghostty.nix` | `theme = "Ayu Mirage"` |
| Helix | `home/common/helix.nix` | `theme = "ayu_mirage"` |
| Zed | `home/common/zed.nix` | `theme.dark = "Ayu Mirage"` |
| Zellij | `home/common/zellij.nix` | Custom Ayu Mirage theme block |
| Starship | `home/common/shell.nix` and `dotfiles/starship/` | Selectable Ayu Mirage or Maison theme |
| bat | via shell alias | Inherits terminal colors |

## Fonts

Font configuration lives in `modules/darwin/fonts.nix` (Linux
servers are headless and do not use GUI fonts):

- **DejaVu SansM Nerd Font** -- Ghostty terminal
- **MesloLGS Nerd Font** -- iTerm2, Zed editor
- **Fira Code Nerd Font** -- available as alternative
- **Symbols Only Nerd Font** -- fallback for Nerd Font glyphs

## Changing the Theme

To switch to a different color scheme:

1. Update `home/common/ghostty.nix` -- change `theme`
2. Update `home/common/helix.nix` -- change `theme`
3. Update `home/common/zed.nix` -- change the theme names in `userSettings.theme`
4. Update `home/common/zellij.nix` -- replace the color hex values in the
   theme block
5. Update `home/common/shell.nix` -- change `starshipTheme` to
   `"ayu-mirage"`, `"maison"`, or `"maison-minimal"`

Then apply with `mise run nix:switch`. The Maison files are copied into this
repository so pure flake evaluation does not depend on the absolute path of a
second checkout. Keep `~/.config/starship.toml` out of Maison's active dotfile
mapping; Home Manager owns the selected prompt configuration.

The four editor/terminal theme files still need to change for full consistency.
The Starship prompt selector is intentionally independent, since the Maison
prompt has its own palette and layout.
