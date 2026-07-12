# home/common/shell.nix
# Cross-platform zsh + starship configuration.
# macOS-specific aliases and PATH entries are guarded with lib.optionals / pkgs.stdenv.isDarwin.
#
# Nerd Font glyphs are encoded via builtins.fromJSON "\uXXXX" so they survive
# editors, formatters, and copy-paste that strip Private Use Area codepoints.
{
  config,
  pkgs,
  lib,
  ...
}:
{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    dotDir = config.home.homeDirectory;
    initContent = ''
      # Restore the shell editing behavior we relied on before nix-darwin.
      autoload -Uz select-word-style up-line-or-beginning-search down-line-or-beginning-search
      select-word-style bash
      zle -N up-line-or-beginning-search
      zle -N down-line-or-beginning-search

      # oh-my-zsh sudo plugin behavior: press Esc Esc to toggle a leading sudo.
      sudo-command-line() {
        local prefix="sudo "
        if [[ "$BUFFER" == "$prefix"* ]]; then
          BUFFER="''${BUFFER#$prefix}"
        else
          BUFFER="$prefix$BUFFER"
        fi
        CURSOR=$#BUFFER
        zle redisplay
      }
      zle -N sudo-command-line

      bindkey "^[[3~" delete-char
      [[ -n "''${terminfo[kdch1]:-}" ]] && bindkey "''${terminfo[kdch1]}" delete-char

      bindkey '\e\e' sudo-command-line

      bindkey "^[[A" up-line-or-beginning-search
      bindkey "^[[B" down-line-or-beginning-search
      [[ -n "''${terminfo[kcuu1]:-}" ]] && bindkey "''${terminfo[kcuu1]}" up-line-or-beginning-search
      [[ -n "''${terminfo[kcud1]:-}" ]] && bindkey "''${terminfo[kcud1]}" down-line-or-beginning-search

      if [[ -f "$HOME/.zshrc.local" ]]; then
        source "$HOME/.zshrc.local"
      fi

      if command -v mise >/dev/null 2>&1; then
        eval "$(mise activate zsh)"
        source <(mise completion zsh)
      fi

      # Navigate up N directories: `up 3` = cd ../../..
      # Dot aliases use this for convenience.
      up() {
        local target=""
        for ((i = 0; i < ''${1:-1}; i++)); do target+="../"; done
        cd "$target" || return
      }
      alias ..='up 1'
      alias ...='up 2'
      alias ....='up 3'
      alias .....='up 4'

      # Default to Helix everywhere, but prefer Zed when inside Zed's terminal.
      if [[ -n "''${ZED_TERM:-}" || -n "''${ZED_WORKTREE_ROOT:-}" ]]; then
        export EDITOR="zed --wait"
        export VISUAL="zed --wait"
        export GIT_EDITOR="zed --wait"
        export GIT_SEQUENCE_EDITOR="zed --wait"
      else
        export EDITOR="hx"
        export VISUAL="hx"
        export GIT_EDITOR="hx"
        export GIT_SEQUENCE_EDITOR="hx"
      fi

      # Ghostty shell integration — manual source to handle cmux's non-standard
      # GHOSTTY_RESOURCES_DIR layout.  Revert to enableZshIntegration = true in
      # ghostty.nix once cmux fixes upstream: https://github.com/manaflow-ai/cmux/issues/1309
      if [[ -n "''${GHOSTTY_RESOURCES_DIR:-}" ]]; then
        source "''${GHOSTTY_RESOURCES_DIR}/shell-integration/zsh/ghostty-integration" 2>/dev/null || \
          source "''${GHOSTTY_RESOURCES_DIR%/ghostty}/shell-integration/ghostty-integration.zsh" 2>/dev/null
      fi

      # cmux/Ghostty can preseed MANPATH too narrowly, which makes macOS `man`
      # lose the system manuals. Rebuild from the default path and preserve any
      # terminal-provided extra entries.
      if [[ -n "''${MANPATH:-}" ]]; then
        typeset -aU default_manpath extra_manpath manpath
        default_manpath=(''${(s/:/)$(env -u MANPATH manpath 2>/dev/null)})
        extra_manpath=(''${(s/:/)MANPATH})
        manpath=($default_manpath $extra_manpath)
      fi

      # git grep to ignore some basic patterns that generally provide no useful results
      gg() {
        git grep "$@" -- ':!*.svg' ':!*.min.js' ':!*.min.css' ':!*/vendor/*.css' ':!*/vendor/*.js'
      }

      md() {
        pi --no-session -nc -nbt --offline --pager "$1"; clear
      }
    '';
    plugins = [
      {
        name = "zsh-syntax-highlighting";
        src = "${pkgs.zsh-syntax-highlighting}/share/zsh-syntax-highlighting";
      }
      {
        name = "zsh-autosuggestions";
        src = "${pkgs.zsh-autosuggestions}/share/zsh-autosuggestions";
      }
    ];
  };

  home.sessionPath = [
    "${config.home.homeDirectory}/.local/bin"
  ]
  ++ lib.optionals pkgs.stdenv.isLinux [
    "/run/current-system/sw/bin"
    "${config.home.homeDirectory}/.nix-profile/bin"
    "${config.home.homeDirectory}/.local/state/nix/profiles/profile/bin"
  ]
  ++ lib.optionals pkgs.stdenv.isDarwin [
    "/opt/homebrew/bin"
    "/opt/homebrew/sbin"
  ];

  home.shellAliases = {
    # ── Tool aliases ─────────────────────────────────────────────────
    ls = "eza";
    less = "bat";
    cat = "bat";
    oc = "opencode";

    # ── Git (portable subset of oh-my-zsh git plugin) ───────────────
    gst = "git status";
    gd = "git diff";
    ga = "git add";
    gc = "git commit --verbose";
    "gc!" = "git commit --verbose --amend";
    gco = "git checkout";
    gdca = "git diff --cached";
    gbD = "git branch --delete --force";
    gbd = "git branch --delete";
  }
  // lib.optionalAttrs pkgs.stdenv.isDarwin {
    # macOS-only aliases
  };

  programs.starship = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    settings = builtins.fromTOML (builtins.readFile ../../dotfiles/starship/starship.toml);
  };
}
