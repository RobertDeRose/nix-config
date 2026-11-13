# home/common/shell.nix
# Cross-platform zsh and prompt configuration.
# macOS-specific aliases and PATH entries are guarded with lib.optionals / pkgs.stdenv.hostPlatform.isDarwin.
#
# Nerd Font glyphs are encoded via builtins.fromJSON "\uXXXX" so they survive
# editors, formatters, and copy-paste that strip Private Use Area codepoints.
{
  config,
  pkgs,
  lib,
  ...
}:
let
  # Helper: decode a JSON-escaped Unicode string into a Nix string.
  nf = s: builtins.fromJSON ''"${s}"'';

  # ── Nerd Font icons (Private Use Area) ──────────────────────────────
  iconCmdDuration = nf ''\uF0E7'';
  iconDirectory = nf ''\uDB83\uDDCF''; # U+F0DCF 󰷏
  iconGitBranch = nf ''\uF417'';
  iconTime = nf ''\uDB82\uDD96''; # U+F0996 󰦖
  osLinux = nf ''\uF17C'';
  osMacos = nf ''\uF302'';

  # nix-homebrew's managed prefix is stable on each supported macOS
  # architecture, so shell startup does not need to invoke `brew` to find it.
  homebrewPrefix = if pkgs.stdenv.hostPlatform.isAarch64 then "/opt/homebrew" else "/usr/local";
  promptOs = if pkgs.stdenv.hostPlatform.isDarwin then osMacos else osLinux;
in
{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    dotDir = config.home.homeDirectory;
    oh-my-zsh = {
      enable = true;
      # The pure-Zsh prompt below owns prompt rendering.
      theme = "";
      extraConfig = ''
        zstyle ':omz:alpha:lib:git' async-prompt off

        # Always retain the completion functions belonging to the configured
        # Zsh package. Long-lived terminal servers may not inherit newer Nix
        # profile variables before they launch a fresh shell.
        fpath=("${pkgs.zsh}/share/zsh/${pkgs.zsh.version}/functions" $fpath)

        # Home Manager adds completion directories from every Nix profile.
        # Canonicalize symlinked duplicates before compinit scans them, and
        # prefer the complete Nix-provided function set over macOS's duplicate.
        typeset -aU _hm_canonical_fpath
        for _hm_fpath_dir in $fpath; do
          [[ -d "$_hm_fpath_dir" ]] || continue
          [[ "$_hm_fpath_dir" == /usr/share/zsh/*/functions ]] && continue
          _hm_canonical_fpath+=("''${_hm_fpath_dir:A}")
        done
        fpath=("''${_hm_canonical_fpath[@]}")
        unset _hm_canonical_fpath _hm_fpath_dir
      '';
      plugins = [
        "git"
        "sudo"
        "colored-man-pages"
        "command-not-found"
        "extract"
        "safe-paste"
        "z"
        "brew"
      ]
      ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [ "macos" ];
    };
    initContent = ''
      # Restore the shell editing behavior we relied on before nix-darwin.
      autoload -Uz select-word-style up-line-or-beginning-search down-line-or-beginning-search
      select-word-style bash
      zle -N up-line-or-beginning-search
      zle -N down-line-or-beginning-search

      # The Oh My Zsh sudo plugin supplies the widget; this keeps its
      # historical Esc Esc binding without reimplementing the widget.
      bindkey "^[[3~" delete-char
      [[ -n "''${terminfo[kdch1]:-}" ]] && bindkey "''${terminfo[kdch1]}" delete-char

      bindkey '\e\e' sudo-command-line

      bindkey "^[[A" up-line-or-beginning-search
      bindkey "^[[B" down-line-or-beginning-search
      [[ -n "''${terminfo[kcuu1]:-}" ]] && bindkey "''${terminfo[kcuu1]}" up-line-or-beginning-search
      [[ -n "''${terminfo[kcud1]:-}" ]] && bindkey "''${terminfo[kcud1]}" down-line-or-beginning-search

      # Keep ordinary Tab on the completion widget that preceded Fzf. Its
      # integration otherwise wraps every Tab press for the optional `**` trigger.
      bindkey '^I' "''${fzf_default_completion:-expand-or-complete}"

      if [[ -f "$HOME/.zshrc.local" ]]; then
        source "$HOME/.zshrc.local"
      fi

      if command -v mise >/dev/null 2>&1; then
        # Export here as well as through Home Manager session variables: a
        # long-lived terminal server can inherit the "already sourced" guard
        # while missing variables introduced by a newer generation.
        export MISE_HOOK_ENV_CHPWD_ONLY=true

        # Capture the real executable before activation replaces `mise` with a
        # shell function, then reuse generated completion until it changes.
        mise_bin="$(whence -p mise)"
        eval "$(mise activate zsh)"
        # Even with chpwd-only checks, mise's stock precmd hook still launches
        # the binary after ordinary commands. Its chpwd hook and command wrapper
        # are sufficient for this workflow.
        add-zsh-hook -d precmd _mise_hook_precmd

        mise_completion_dir="''${XDG_CACHE_HOME:-$HOME/.cache}/mise"
        mise_completion="$mise_completion_dir/completion.zsh"
        if [[ ! -s "$mise_completion" || "$mise_bin" -nt "$mise_completion" ]]; then
          mkdir -p "$mise_completion_dir"
          mise_completion_tmp="$mise_completion.$$"
          if mise completion zsh >| "$mise_completion_tmp"; then
            mv -f "$mise_completion_tmp" "$mise_completion"
          else
            rm -f "$mise_completion_tmp"
          fi
        fi
        if [[ -s "$mise_completion" ]]; then
          source "$mise_completion"
        else
          source <(mise completion zsh)
        fi
      fi

      # Navigate up N directories: `up 3` = cd ../../..
      # Dot aliases use this for convenience.
      up() {
        local target=""
        for ((i = 0; i < ''${1:-1}; i++)); do target+="../"; done
        cd "$target" || return
      }
      # Oh My Zsh already provides `...`, `....`, and `.....`; retain only
      # the custom `up N` helper and its one-level shorthand.
      alias ..='up 1'

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

      # Ghostty/cmux already reports the working directory and terminal title.
      # Avoid Oh My Zsh's duplicate OSC 7/title hooks; its URL encoder is
      # particularly expensive for deeply nested working directories.
      if [[ -n "''${GHOSTTY_RESOURCES_DIR:-}" || -n "''${CMUX_SHELL_INTEGRATION:-}" ]]; then
        DISABLE_AUTO_TITLE=true
        add-zsh-hook -d precmd omz_termsupport_precmd
        add-zsh-hook -d precmd omz_termsupport_cwd
        add-zsh-hook -d preexec omz_termsupport_preexec
      fi

      # Zsh-z only needs to record a directory when it changes. Tracking on
      # every prompt adds avoidable file-write work after every command while
      # providing no extra navigation value.
      if (( $+functions[_zshz_precmd] )); then
        add-zsh-hook -d precmd _zshz_precmd
        __zshz_track_directory() {
          _zshz_precmd
        }
        add-zsh-hook chpwd __zshz_track_directory
        __zshz_track_directory
      fi

      # cmux/Ghostty can preseed MANPATH too narrowly, which makes macOS `man`
      # lose the system manuals. Keep Homebrew's path without invoking
      # `manpath` unless the terminal-provided value is missing / incomplete.
      if [[ -n "''${HOMEBREW_PREFIX:-}" && -d "''${HOMEBREW_PREFIX}/share/man" ]]; then
        case ":''${MANPATH:-}:" in
          *:"''${HOMEBREW_PREFIX}/share/man":*) ;;
          *) export MANPATH="''${HOMEBREW_PREFIX}/share/man''${MANPATH:+:$MANPATH}" ;;
        esac
      fi
      if [[ -n "''${HOMEBREW_PREFIX:-}" && -d "''${HOMEBREW_PREFIX}/share/info" ]]; then
        case ":''${INFOPATH:-}:" in
          *:"''${HOMEBREW_PREFIX}/share/info":*) ;;
          *) export INFOPATH="''${HOMEBREW_PREFIX}/share/info''${INFOPATH:+:$INFOPATH}" ;;
        esac
      fi
      if [[ -n "''${MANPATH:-}" && ":$MANPATH:" != *:/usr/share/man:* ]]; then
        typeset -aU default_manpath extra_manpath manpath
        default_manpath=(''${(s/:/)$(env -u MANPATH manpath 2>/dev/null)})
        extra_manpath=(''${(s/:/)MANPATH})
        manpath=($default_manpath $extra_manpath)
      fi

      # `gg` belongs to the Oh My Zsh git plugin. Keep Maison's filtered
      # git grep helper under a distinct name instead of overriding it.
      ggrep() {
        git grep "$@" -- ':!*.svg' ':!*.min.js' ':!*.min.css' ':!*/vendor/*.css' ':!*/vendor/*.js'
      }

      # `lab <host>`: open a root shell on a lab host. If root does not yet
      # accept key auth, log in as `service`, `su` to root (prompts for the
      # root password), and append a public key to root's authorized_keys.
      # The key comes from LAB_SSH_PUBKEY (a .pub path) or the SSH agent.
      lab() {
        emulate -L zsh
        if (( $# != 1 )) || [[ -z "$1" || "$1" == -* ]]; then
          print -u2 "usage: lab <host>"
          return 2
        fi
        local host="$1" pubkey label root_script
        local -a keys labels

        if ssh -o BatchMode=yes -o ConnectTimeout=10 "root@$host" true 2>/dev/null; then
          ssh "root@$host"
          return
        fi

        if [[ -n "''${LAB_SSH_PUBKEY:-}" ]]; then
          if [[ ! -r "$LAB_SSH_PUBKEY" ]]; then
            print -u2 "lab: cannot read LAB_SSH_PUBKEY ($LAB_SSH_PUBKEY)"
            return 1
          fi
          keys=("''${(@f)$(<"$LAB_SSH_PUBKEY")}")
        else
          keys=("''${(@f)$(ssh-add -L 2>/dev/null)}")
        fi
        keys=("''${(@M)keys:#(ssh-|ecdsa-|sk-)*}")
        if (( ''${#keys} == 0 )); then
          print -u2 "lab: no SSH public key found; unlock the Bitwarden SSH agent or set LAB_SSH_PUBKEY"
          return 1
        elif (( ''${#keys} == 1 )); then
          pubkey="''${keys[1]}"
        else
          for pubkey in "''${keys[@]}"; do
            labels+=("''${pubkey[(w)1]} ''${pubkey[(w)3,-1]}")
          done
          pubkey=""
          local PS3="Key to authorize for root@$host: "
          select label in "''${labels[@]}"; do
            [[ -n "$label" ]] && { pubkey="''${keys[REPLY]}"; break; }
          done
          [[ -n "$pubkey" ]] || return 1
        fi

        root_script='set -e
      f=/root/.ssh/authorized_keys
      umask 077
      mkdir -p /root/.ssh
      chmod 700 /root/.ssh
      touch "$f"
      chmod 600 "$f"
      if [ -s "$f" ] && [ -n "$(tail -c 1 "$f")" ]; then echo >> "$f"; fi
      if grep -qxF -- "$key" "$f"; then
        echo "lab: key already authorized for root"
      else
        printf "%s\n" "$key" >> "$f"
        echo "lab: key authorized for root"
      fi'
        root_script="key=''${(qq)pubkey}"$'\n'"$root_script"

        print -u2 "lab: setting up root key auth on $host via service (enter the root password)"
        ssh -t "service@$host" "su -c ''${(qq)root_script}" || {
          print -u2 "lab: key setup on $host failed"
          return 1
        }
        ssh "root@$host"
      }

      # Render the prompt in Zsh itself. Only Git status uses an external
      # process; directory, time, duration, and exit status are shell-native.
      zmodload zsh/datetime
      typeset -gF __prompt_command_started=0

      __prompt_preexec() {
        __prompt_command_started=$EPOCHREALTIME
      }

      __prompt_git_status() {
        REPLY=""
        local status_output line branch oid xy
        local ahead=0 behind=0 stashes=0
        local staged=0 modified=0 untracked=0 conflicted=0
        local -a fields

        status_output="$(GIT_OPTIONAL_LOCKS=0 command git status \
          --porcelain=v2 --branch --show-stash 2>/dev/null)" || return

        while IFS= read -r line; do
          case "$line" in
            '# branch.head '*) branch="''${line#\# branch.head }" ;;
            '# branch.oid '*) oid="''${line#\# branch.oid }" ;;
            '# branch.ab '*)
              fields=(''${(z)line})
              ahead="''${fields[3]#+}"
              behind="''${fields[4]#-}"
              ;;
            '# stash '*) stashes="''${line#\# stash }" ;;
            '1 '*|'2 '*)
              fields=(''${(z)line})
              xy=$fields[2]
              [[ "''${xy[1]}" != "." ]] && staged=1
              [[ "''${xy[2]}" != "." ]] && modified=1
              ;;
            'u '*) conflicted=1 ;;
            '? '*) untracked=1 ;;
          esac
        done <<< "$status_output"

        [[ -n "$branch" ]] || return
        [[ "$branch" == "(detached)" ]] && branch="@''${oid[1,8]}"
        branch="''${branch//\%/%%}"
        (( ''${#branch} > 42 )) && branch="''${branch[1,41]}…"

        local details=""
        (( staged )) && details+="+"
        (( modified )) && details+="!"
        (( untracked )) && details+="?"
        (( conflicted )) && details+="="
        (( ahead )) && details+="↑$ahead"
        (( behind )) && details+="↓$behind"
        (( stashes )) && details+="≡$stashes"

        REPLY=" %F{150}${iconGitBranch} $branch%f"
        [[ -n "$details" ]] && REPLY+=" %F{222}$details%f"
      }

      __prompt_precmd() {
        local last_status=$?
        local git_segment="" duration_segment="" prompt_character
        local -F 1 elapsed=0

        if (( __prompt_command_started > 0 )); then
          elapsed=$(( EPOCHREALTIME - __prompt_command_started ))
          if (( elapsed >= 0.5 )); then
            duration_segment=" %F{215}${iconCmdDuration} ''${elapsed}s%f"
          fi
        fi
        __prompt_command_started=0

        __prompt_git_status
        git_segment=$REPLY

        if (( last_status == 0 )); then
          prompt_character='%F{150}$%f'
        else
          prompt_character='%F{210}$%f'
        fi

        PROMPT="%F{240}╭─%f %F{183}${promptOs}%f %F{189}%n%f %F{111}${iconDirectory} %2~%f$git_segment$duration_segment %F{217}${iconTime} %D{%H:%M}%f"$'\n'"%F{240}╰─%f $prompt_character "
        RPROMPT=""
      }

      autoload -Uz add-zsh-hook
      add-zsh-hook preexec __prompt_preexec
      add-zsh-hook precmd __prompt_precmd
      preexec_functions=(__prompt_preexec ''${preexec_functions:#__prompt_preexec})
      precmd_functions=(__prompt_precmd ''${precmd_functions:#__prompt_precmd})
    '';
  };

  home.sessionVariables = {
    # `ls` is provided by eza below, so skip Oh My Zsh's slow BSD `ls -G`
    # capability probe and preserve the intended colored listing behavior.
    DISABLE_LS_COLORS = "true";
    # Mise only needs a full environment check after `cd`; avoid rerunning it
    # after every command while retaining immediate directory-change updates.
    MISE_HOOK_ENV_CHPWD_ONLY = "true";
  }
  // lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
    # Keep the values normally supplied by `brew shellenv` without spawning
    # Homebrew for every interactive shell. The brew and OMZ plugins use these
    # variables to locate the managed installation and its zsh functions.
    HOMEBREW_PREFIX = homebrewPrefix;
    HOMEBREW_CELLAR = "${homebrewPrefix}/Cellar";
    HOMEBREW_REPOSITORY = "${homebrewPrefix}/Library/.homebrew-is-managed-by-nix";
  };

  home.sessionPath = [
    "${config.home.homeDirectory}/bin"
    "${config.home.homeDirectory}/.local/bin"
  ]
  ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
    "/run/current-system/sw/bin"
    "${config.home.homeDirectory}/.nix-profile/bin"
    "${config.home.homeDirectory}/.local/state/nix/profiles/profile/bin"
  ]
  ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
    "/opt/homebrew/bin"
    "/opt/homebrew/sbin"
  ];

  home.shellAliases = {
    # ── Maison tool aliases ──────────────────────────────────────────
    ls = "eza --icons=auto --git";
    lla = "eza -la --icons=auto --git";
    lt = "eza --tree --icons=auto --git";
    less = "bat";
    cat = "bat";
    # Executables cannot mutate their parent shell, so evaluate only the
    # assignment/unset command emitted by these Home Manager-managed helpers.
    "bw-unlock" = ''eval "$("$HOME/.local/bin/bw-unlock" --shell)"'';
    "bw-lock" = ''eval "$("$HOME/.local/bin/bw-lock" --shell)"'';
  }
  // lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
    # macOS-only aliases
  };

  programs.starship = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = false;
    # Starship drives Bash only; Zsh uses the native prompt above.
    settings = builtins.fromTOML (builtins.readFile ../../dotfiles/starship/maison.toml);
  };
}
