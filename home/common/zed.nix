{ lib, ... }:
{
  programs.zed-editor = {
    enable = true;

    userSettings = {
      base_keymap = "VSCode";
      vim_mode = true;
      helix_mode = true;

      line_indicator_format = "long";
      preferred_line_length = 120;
      minimap.show = "auto";

      ui_font_size = 16;
      buffer_font_size = 15;

      terminal = {
        font_family = "MesloLGS NF";
        font_size = 14;
      };

      hard_tabs = false;
      tab_size = 2;
      format_on_save = "on";
      ensure_final_newline_on_save = true;
      remove_trailing_whitespace_on_save = true;

      edit_predictions.provider = "copilot";

      theme = {
        mode = "dark";
        light = "Dracula Light (Alucard)";
        dark = "Ayu Mirage";
      };
    };

    userKeymaps = [
      {
        context = "Workspace";
        bindings = {
          "ctrl-s" = "workspace::Save";
          "ctrl-p" = "file_finder::Toggle";
          "ctrl-shift-p" = "command_palette::Toggle";
          "ctrl-b" = "project_panel::ToggleFocus";
          "ctrl-/" = "editor::ToggleComments";
        };
      }
      {
        context = "Editor";
        bindings = {
          "alt-up" = "editor::MoveLineUp";
          "alt-down" = "editor::MoveLineDown";
        };
      }
      {
        context = "Terminal";
        bindings = {
          "ctrl-n" = [
            "terminal::SendKeystroke"
            "ctrl-n"
          ];
        };
      }
    ];

    installRemoteServer = lib.mkDefault true;
  };
}
