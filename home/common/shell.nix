# home/common/shell.nix
# Cross-platform zsh + starship configuration.
# macOS-specific aliases and PATH entries are guarded with lib.optionals / pkgs.stdenv.isDarwin.
#
# Nerd Font glyphs are encoded via builtins.fromJSON "\uXXXX" so they survive
# editors, formatters, and copy-paste that strip Private Use Area codepoints.
{
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
in
{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    initContent = ''
      export PATH="$PATH:$HOME/.local/bin"

      # Navigate up N directories: `up 3` = cd ../../..
      # Dot aliases use this for convenience.
      up() {
        local path=""
        for ((i = 0; i < ''${1:-1}; i++)); do path+="../"; done
        cd "$path" || return
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

  # macOS-specific PATH additions (Homebrew)
  home.sessionPath = lib.optionals pkgs.stdenv.isDarwin [
    "/opt/homebrew/bin"
    "/opt/homebrew/sbin"
  ];

  home.shellAliases = {
    # ── Directory shortcuts ──────────────────────────────────────────
    work = "cd ~/workspace/checkpoint";
    personal = "cd ~/workspace/personal";
    apollo = "cd ~/workspace/checkpoint/apollo";

    # ── Tool aliases ─────────────────────────────────────────────────
    ls = "eza";
    less = "bat";
    cat = "bat";
    oc = "opencode";
    cgb = "clean_git_branches";

    # ── Git (portable subset of oh-my-zsh git plugin) ───────────────
    gst = "git status";
    gd = "git diff";
    ga = "git add";
    gc = "git commit --verbose";
    "gc!" = "git commit --verbose --amend";
    gco = "git checkout";
    gdca = "git diff --cached";
    gbD = "git branch --delete --force";
  }
  // lib.optionalAttrs pkgs.stdenv.isDarwin {
    # macOS-only aliases
    docker = "container";
  };

  programs.starship = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    settings = {
      continuation_prompt = "[ ▶▶](fg:lightgreen) ";
      format = lib.concatStrings [
        "[╭──](fg:current_line)"
        "$os"
        "$directory"
        "$git_branch"
        "$fill"
        "$sudo"
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
        format = "[$symbol](yellow)";
        symbol = iconSudo;
        disabled = false;
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
    };
  };
}
