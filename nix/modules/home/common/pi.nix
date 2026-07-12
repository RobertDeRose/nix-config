# Pi coding agent interface customization.
{
  lib,
  pkgs,
  inputs,
  ...
}:
let
  piPackage = import ../../../packages/custom/llmagents.nix {
    inherit inputs pkgs;
    name = "pi";
  };
  settingsDefaults = ../../../../dotfiles/pi/settings.defaults.json;
in
{
  home.packages = [ piPackage ];

  home.file.".pi/agent/themes/ayu-mirage.json".source = ../../../../dotfiles/pi/themes/ayu-mirage.json;
  home.file.".pi/agent/extensions/ayu-footer.ts".source = ../../../../dotfiles/pi/extensions/footer.ts;
  home.file.".pi/agent/extensions/markdown-pager.ts".source = ../../../../dotfiles/pi/extensions/pager.ts;
  home.file.".pi/agent/extensions/bookmark.ts".source = ../../../../dotfiles/pi/extensions/bookmark.ts;
  home.file.".pi/agent/AGENTS.md".source = ../../../../dotfiles/pi/AGENTS.md;

  home.activation.backupOldPiOverlayExtension = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    old_extension="$HOME/.pi/agent/extensions/interface-overlays.ts"
    if [ -e "$old_extension" ]; then
      backup_dir="$HOME/.local/state/nix-config/backups/pi"
      timestamp="$(${pkgs.coreutils}/bin/date -u +%Y%m%dT%H%M%SZ)"
      mkdir -p "$backup_dir"
      backup_path="$backup_dir/interface-overlays.ts.$timestamp"
      mv "$old_extension" "$backup_path"
      echo "Backed up obsolete Pi extension to $backup_path" >&2
    fi
  '';

  # Pi mutates settings.json through /settings. Merge checked-in defaults after
  # each switch while retaining additional package entries selected by the user.
  home.activation.configurePiInterface = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    settings_file="$HOME/.pi/agent/settings.json"
    mkdir -p "$(dirname "$settings_file")"
    if [ ! -s "$settings_file" ]; then
      printf '{}\n' > "$settings_file"
      chmod 600 "$settings_file"
    fi
    tmp_file="$(${pkgs.coreutils}/bin/mktemp)"
    if ${pkgs.jq}/bin/jq --slurpfile defaults ${settingsDefaults} '
      . * $defaults[0]
      | .packages = (((.packages // []) + ($defaults[0].packages // [])) | unique)
    ' "$settings_file" > "$tmp_file"; then
      mv "$tmp_file" "$settings_file"
      chmod 600 "$settings_file"
    else
      rm -f "$tmp_file"
      echo "warning: could not update Pi settings at $settings_file" >&2
    fi
  '';
}
