{pkgs, ...}: {
  programs.helix = {
    enable = true;

    settings = {
      theme = "ayu_mirage";

      editor = {
        line-number = "relative";
        mouse = true;
        color-modes = true;
        cursorline = true;
        completion-timeout = 80;
        true-color = true;
        auto-save = false;
        auto-format = true;
        bufferline = "multiple";
        rulers = [100 120];
        soft-wrap.enable = false;
      };

      keys = {
        normal = {
          C-s = ":w";
          C-p = "file_picker";
          C-b = "file_explorer";
          C-slash = "toggle_comments";
          A-up = ["extend_to_line_bounds" "delete_selection" "move_line_up" "paste_before"];
          A-down = ["extend_to_line_bounds" "delete_selection" "paste_after"];
        };
      };
    };

    languages = {
      language-server.harper-ls = {
        command = "harper-ls";
        args = ["--stdio"];
      };

      language-server.rumdl = {
        command = "rumdl";
        args = ["server"];
      };

      language = [
        {
          name = "markdown";
          language-servers = ["marksman" "harper-ls" "markdown-oxide"];
        }
      ];
    };
  };

  home.packages = with pkgs; [
    harper
    marksman
    markdown-oxide
    rumdl
  ];
}
