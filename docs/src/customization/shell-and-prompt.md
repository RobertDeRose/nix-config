# Shell and prompt

Static shell configuration is native code under `dotfiles/zsh/` and `dotfiles/starship/`. Home Manager enables Zsh and Starship, installs integrations, and sources the checked-in fragments. Package-output-dependent paths remain small generated fragments in `nix/modules/home/common/shell.nix`.

Maison uses a Powerlevel10k-inspired, two-line Starship prompt on macOS and Linux. The prompt uses the Catppuccin Macchiato palette and Nerd Font glyphs, but every module stays left-aligned. It deliberately avoids Starship `$fill`, `right_format`, and full-width prompt geometry because those layouts are sensitive to terminal glyph-width differences.

The terminal running the shell must use a Nerd Font. For SSH sessions, that means configuring the font in the local terminal emulator; the remote host does not need the font files installed.

Linux hosts use `C.UTF-8` for both `LANG` and `LC_CTYPE`. Maison sets the locale in the system configuration, Home Manager session, and bootstrap environment so Zsh can decode pasted glyphs and calculate prompt widths consistently. `LC_ALL` remains unset so individual locale categories can still be overridden.

The primary files are:

| File | Purpose |
| --- | --- |
| `dotfiles/starship/starship.toml` | Default Maison Macchiato prompt |
| `dotfiles/starship/starship-minimal.toml` | ASCII recovery prompt for basic consoles and incompatible terminals |

Home Manager also installs the recovery prompt as `~/.config/starship/minimal.toml`. To diagnose a terminal rendering problem without modifying Maison, run:

```bash
export STARSHIP_CONFIG="$HOME/.config/starship/minimal.toml"
exec zsh -l
```

Edit the native file, then run `maison plan` and `maison apply`.
