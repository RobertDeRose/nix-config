# Shell and prompt

Static shell configuration is native code under `dotfiles/zsh/` and `dotfiles/starship/starship.toml`. Home Manager enables Zsh and Starship, installs integrations, and sources the checked-in fragments. Package-output-dependent paths remain small generated fragments in `nix/modules/home/common/shell.nix`.

Edit the native file, then run `maison plan` and `maison apply`.
