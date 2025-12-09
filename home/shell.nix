{
  pkgs,
  lib,
  ...
} : let
  /*
    Function to generate the pill format info block.

    Arguments:
    symbol: The icon/symbol for the pill (e.g., "⭐")
    info: The version/info text (e.g., "v1.2.3")
    color: color name (e.g., "primary") -
  */
  makePill = symbol: info: color:
    lib.concatStrings [
      "[─](fg:current_line)"
      "[](fg:${color})"
      "[${symbol}](fg:primary bg:${color})"
      "[](fg:${color} bg:box)"
      "[ ${info}](fg:foreground bg:box)"
      "[](fg:box)"
    ];

in {
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    initContent = ''
      export PATH="$PATH:$HOME/.local/bin"
    '';
    oh-my-zsh = {
      enable = true;
      plugins = [
        "brew"
        "docker"
        "docker-compose"
        # "dstroy"
        "git"
        "git-extras"
        "sudo"
        "uv"
      ];
    };
    plugins = [
      {
        name = "zsh-syntax-highlighting";
        src = pkgs.zsh-syntax-highlighting;
      }
    ];
  };

  home.shellAliases = {
    # zsh
    zshconfig = "code ~/.zshrc";
    ohmyzsh = "code ~/.oh-my-zsh";
    # work dirs
    work = "cd ~/workspace/checkpoint";
    personal = "cd ~/workspace/personal";
    neo = "cd ~/workspace/checkpoint/neo";
    apollo = "cd ~/workspace/checkpoint/apollo";
    rps = "cd ~/workspace/checkpoint/rps";
    mpos = "cd ~/workspace/checkpoint/mpos";
    # VMs
    focal = "limactl shell focal";
    jammy = "limactl shell jammy";
    # app alias
    sftp = "rlwrap sftp";
    less = "bat";
    cat = "bat";
    docker = "container";
    compose = "docker compose";
  };

  programs.starship = {
    enable = true;

    enableBashIntegration = true;
    enableZshIntegration = true;

    settings = {
      continuation_prompt = "[ ▶▶ ](fg:lightgreen)";
      format = lib.concatStrings [
        "[╭─](fg:current_line)"
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
      palette = "dracula";
      palettes.dracula = {
        background = "#282A36";
        black = "#000000";
        blue = "#6272A4";
        box = "#44475A";
        brightblue = "#89b4fa";
        current_line = "#44475A";
        cyan = "#8BE9FD";
        foreground = "#F8F8F2";
        green = "#50FA7B";
        lavender = "#b4befe";
        lightgreen = "#a6e3a1";
        maroon = "#eba0ac";
        orange = "#FFB86C";
        orangeyellow = "#f9e2af";
        peach = "#fab387";
        pink = "#FF79C6";
        primary = "#1E1F29";
        purple = "#BD93F9";
        red = "#FF5555";
        sapphire = "#74c7ec";
        sky = "#89dceb";
        teal = "#94e2d5";
        white = "#ffffff";
        yellow = "#F1FA8C";
      };
      os = {
        disabled = false;
        format = "(fg:current_line)[](fg:foreground)[$symbol](fg:primary bg:foreground)[](fg:foreground)";
        symbols = {
          Alpine = "";
          Amazon = "";
          Android = "";
          Arch = "";
          CentOS = "";
          Debian = "";
          EndeavourOS = "";
          Fedora = "";
          FreeBSD = "";
          Garuda = "";
          Gentoo = "";
          Linux = "";
          Macos = "";
          Manjaro = "";
          Mariner = "";
          Mint = "";
          NetBSD = "";
          NixOS = "";
          OpenBSD = "";
          OpenCloudOS = "";
          openEuler = "";
          openSUSE = "";
          OracleLinux = "⊂⊃";
          Pop = "";
          Raspbian = "";
          Redhat = "";
          RedHatEnterprise = "";
          Solus = "";
          SUSE = "";
          Ubuntu = "";
          Unknown = "";
          Windows = "";
        };
      };

      directory = {
        format = makePill "󰷏" " $read_only$truncation_symbol$path" "blue";
        home_symbol = " ";
        read_only = "󱧵 ";
        read_only_style = "";
        truncation_length = 2;
        truncation_symbol = " ";
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
        symbol = "";
        disabled = false;
      };

      c = {
        format = makePill "$symbol" "$version" "blue";
        symbol = "";
      };

      cmd_duration = {
        format = makePill "" "$duration " "orange";
        min_time = 500;
      };

      git_branch = {
        format = makePill "$symbol" "$branch" "lightgreen";
        symbol = " ";
      };

      nodejs = {
        format = makePill "$symbol" "$version" "green";
        symbol = "󰎙 ";
      };

      python = {
        format = makePill "$symbol" "$version" "brightblue";
        symbol = "";
      };

      rust = {
        format = makePill "$symbol" "$version" "red";
        symbol = "";
      };

      shell = {
        disabled = false;
        fish_indicator = "fish";
        format = makePill "" "$indicator" "blue";
        powershell_indicator = "powershell";
        unknown_indicator = "shell";
      };

      time = {
        disabled = false;
        format = makePill "󰦖" "$time" "purple";
        time_format = "%H:%M";
      };

      username = {
        format = makePill "" "$user" "sapphire";
        show_always = true;
      };
    };
  };
}
