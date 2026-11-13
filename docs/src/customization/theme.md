# Theme Consistency

The [Ayu Mirage](https://github.com/ayu-theme) color palette is used across all
configured editors and terminals. The prompts use their own palettes.

## Where Ayu Mirage Is Applied

| Tool | Config File | Theme Setting |
|------|------------|---------------|
| Ghostty | `home/common/ghostty.nix` | `theme = "Ayu Mirage"` |
| Helix | `home/common/helix.nix` | `theme = "ayu_mirage"` |
| Zed | `home/common/zed.nix` | `theme.dark = "Ayu Mirage"` |
| bat | via shell alias | Inherits terminal colors |

## Fonts

Font configuration lives in `modules/darwin/fonts.nix` (Linux
servers are headless and do not use GUI fonts):

- **DejaVu SansM Nerd Font** -- Ghostty terminal
- **MesloLGS Nerd Font** -- Zed editor
- **Fira Code Nerd Font** -- available as alternative
- **Symbols Only Nerd Font** -- fallback for Nerd Font glyphs

## Changing the Theme

To switch to a different color scheme:

1. Update `home/common/ghostty.nix` -- change `theme`
2. Update `home/common/helix.nix` -- change `theme`
3. Update `home/common/zed.nix` -- change the theme names in `userSettings.theme`

Then apply with `mise run nix:switch`.

The Zsh prompt colors live in `home/common/shell.nix`. The Bash Starship prompt
uses `dotfiles/starship/maison.toml`, copied into this repository so pure flake
evaluation does not depend on a second checkout. Keep `~/.config/starship.toml`
out of Maison's active dotfile mapping; Home Manager owns it.
