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
  # makePill icons
  iconCmdDuration = nf ''\uF0E7'';
  iconDirectory = nf ''\uDB83\uDDCF''; # U+F0DCF 󰷏
  iconShell = nf ''\uF489'';
  iconTime = nf ''\uDB82\uDD96''; # U+F0996 󰦖
  iconUsername = nf ''\uF21B'';

  # Module symbols
  iconC = nf ''\uE61E'';
  iconGitBranch = nf ''\uF417'';
  iconNodejs = nf ''\uDB80\uDF99''; # U+F0399 󰎙
  iconPython = nf ''\uE73C'';
  iconRust = nf ''\uE68B'';
  iconSudo = nf ''\uF13E'';

  # Directory
  iconHome = nf ''\uF015'';
  iconTruncation = nf ''\uEBDF'';
  iconReadOnly = nf ''\uDB86\uDDF5''; # U+F19F5 󱧵

  # OS symbols
  osAlpine = nf ''\uF300'';
  osAmazon = nf ''\uF270'';
  osAndroid = nf ''\uE70E'';
  osArch = nf ''\uF303'';
  osCentOS = nf ''\uF304'';
  osDebian = nf ''\uF306'';
  osEndeavourOS = nf ''\uF322'';
  osFedora = nf ''\uF30A'';
  osFreeBSD = nf ''\uF30C'';
  osGaruda = nf ''\uF17C'';
  osGentoo = nf ''\uF30D'';
  osLinux = nf ''\uF17C'';
  osMacos = nf ''\uF302'';
  osManjaro = nf ''\uF312'';
  osMariner = nf ''\uF17C'';
  osMint = nf ''\uF30E'';
  osNetBSD = nf ''\uF17C'';
  osNixOS = nf ''\uF313'';
  osOpenBSD = nf ''\uF328'';
  osOpenCloudOS = nf ''\uEBAA'';
  osopenEuler = nf ''\uF17C'';
  osopenSUSE = nf ''\uF314'';
  osPop = nf ''\uF32A'';
  osRaspbian = nf ''\uF315'';
  osRedhat = nf ''\uF316'';
  osRedHatEnterprise = nf ''\uF316'';
  osSolus = nf ''\uF32D'';
  osSUSE = nf ''\uF314'';
  osUbuntu = nf ''\uF31B'';
  osUnknown = nf ''\uF108'';
  osWindows = nf ''\uE70F'';

  # Powerline glyphs used in makePill
  plRight = nf ''\uE0B6'';
  plLeft = nf ''\uE0B4'';

  # ── makePill: generates a starship "pill" segment ───────────────────
  makePill =
    symbol: info: color:
    lib.concatStrings [
      "[─](fg:current_line)"
      "[${plRight}](fg:${color})"
      "[${symbol}](fg:primary bg:${color})"
      "[${plLeft}](fg:${color} bg:box)"
      "[ ${info}](fg:foreground bg:box)"
      "[${plLeft}](fg:box)"
    ];

  # Starship remains available for Bash and manual use, but Zsh uses the
  # synchronous-process-free prompt below.
  starshipTheme = "maison";
  starshipThemeFiles = {
    maison = ../../dotfiles/starship/maison.toml;
    maison-minimal = ../../dotfiles/starship/maison-minimal.toml;
  };

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

      # `md` belongs to the Oh My Zsh core aliases. Keep Maison's Markdown
      # pager helper under a distinct name instead of overriding it.
      mdview() {
        pi --no-session -nc -nbt --offline --pager "$1"; clear
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
    oc = "opencode";
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
    settings =
      if starshipTheme == "ayu-mirage" then
        {
          continuation_prompt = "[ ▶▶](fg:lightgreen) ";
          format = lib.concatStrings [
            "[╭──](fg:current_line)"
            "$os"
            "$directory"
            "$git_branch"
            "$fill"
            "$nodejs"
            "$rust"
            "$python"
            "$c$cmd_duration"
            "$shell"
            "$time"
            "$username"
            "$line_break"
            "[╰─](fg:current_line)"
            "$character"
          ];
          palette = "ayu_mirage";
          palettes.ayu_mirage = {
            background = "#1F2430";
            black = "#191E2A";
            blue = "#73D0FF";
            box = "#44475A";
            brightblue = "#59C2FF";
            current_line = "#44475A";
            cyan = "#95E6CB";
            foreground = "#CBCCC6";
            green = "#AAD94C";
            lavender = "#D4BFFF";
            lightgreen = "#D5FF80";
            maroon = "#F28779";
            orange = "#FFAD66";
            orangeyellow = "#FFD173";
            peach = "#FFCC66";
            pink = "#F29E74";
            primary = "#1F2430";
            purple = "#D4BFFF";
            red = "#F28779";
            sapphire = "#5CCFE6";
            sky = "#73D0FF";
            teal = "#95E6CB";
            white = "#FFFFFF";
            yellow = "#FFD173";
          };
          os = {
            disabled = false;
            format = "(fg:current_line)[${plRight}](fg:foreground)[$symbol](fg:primary bg:foreground)[${plLeft}](fg:foreground)";
            symbols = {
              Alpine = osAlpine;
              Amazon = osAmazon;
              Android = osAndroid;
              Arch = osArch;
              CentOS = osCentOS;
              Debian = osDebian;
              EndeavourOS = osEndeavourOS;
              Fedora = osFedora;
              FreeBSD = osFreeBSD;
              Garuda = osGaruda;
              Gentoo = osGentoo;
              Linux = osLinux;
              Macos = osMacos;
              Manjaro = osManjaro;
              Mariner = osMariner;
              Mint = osMint;
              NetBSD = osNetBSD;
              NixOS = osNixOS;
              OpenBSD = osOpenBSD;
              OpenCloudOS = osOpenCloudOS;
              openEuler = osopenEuler;
              openSUSE = osopenSUSE;
              OracleLinux = "⊂⊃";
              Pop = osPop;
              Raspbian = osRaspbian;
              Redhat = osRedhat;
              RedHatEnterprise = osRedHatEnterprise;
              Solus = osSolus;
              SUSE = osSUSE;
              Ubuntu = osUbuntu;
              Unknown = osUnknown;
              Windows = osWindows;
            };
          };
          directory = {
            format = makePill iconDirectory "$read_only$truncation_symbol$path" "blue";
            home_symbol = "${iconHome} ";
            read_only = "${iconReadOnly} ";
            read_only_style = "";
            truncation_length = 2;
            truncation_symbol = "${iconTruncation} ";
          };
          character = {
            format = "[$symbol](fg:current_line) ";
            error_symbol = "[!](fg:bold red)";
            success_symbol = "[\\$](fg:lightgreen)";
          };
          fill = {
            style = "fg:current_line";
            symbol = "─";
          };
          sudo = {
            # The sudo module shells out to `sudo -n true` on every prompt render.
            # That adds avoidable latency and has caused prompt-time interference
            # during interactive git workflows, so keep it disabled.
            disabled = true;
            format = "[$symbol](yellow)";
            symbol = iconSudo;
          };
          c = {
            format = makePill "$symbol" "$version" "blue";
            symbol = "${iconC} C";
          };
          cmd_duration = {
            format = makePill iconCmdDuration "$duration " "orange";
            min_time = 500;
          };
          git_branch = {
            format = makePill "$symbol" "$branch" "green";
            symbol = "${iconGitBranch} ";
          };
          nodejs = {
            format = makePill "$symbol" "$version" "green";
            symbol = "${iconNodejs} Node.js";
          };
          python = {
            format = makePill "$symbol" "$version" "brightblue";
            symbol = iconPython;
          };
          rust = {
            format = makePill "$symbol" "$version" "red";
            symbol = iconRust;
          };
          shell = {
            disabled = false;
            fish_indicator = "fish";
            format = makePill iconShell "$indicator" "blue";
            powershell_indicator = "powershell";
            unknown_indicator = "shell";
          };
          time = {
            disabled = false;
            format = makePill iconTime "$time" "purple";
            time_format = "%H:%M";
          };
          username = {
            format = makePill iconUsername "$user" "sapphire";
            show_always = true;
          };
        }
      else
        builtins.fromTOML (builtins.readFile (builtins.getAttr starshipTheme starshipThemeFiles));
  };
}
