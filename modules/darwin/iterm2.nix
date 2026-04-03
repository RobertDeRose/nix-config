# modules/darwin/iterm2.nix
# Manage iTerm2 settings declaratively.
#
# Strategy: store the exported plist in config/iterm2/ and tell iTerm2 to load
# preferences from a Nix-managed location. On activation, the plist is copied
# (not symlinked — iTerm2 writes back to it) and the custom-folder pref is set.
#
# To re-export after changing settings in iTerm2:
#   mise run nix:iterm-export
{ username, ... }:
let
  prefsDir = "/Users/${username}/Library/Application Support/iTerm2/nix-managed";
  plistSrc = ../../config/iterm2/com.googlecode.iterm2.plist;
in {
  # Point iTerm2 at the nix-managed prefs folder
  system.defaults.CustomUserPreferences."com.googlecode.iterm2" = {
    LoadPrefsFromCustomFolder = true;
    PrefsCustomFolder         = prefsDir;
    NoSyncNeverRemindPrefsChangesLostForFile_Selection = 2; # don't nag about prefs changes
  };

  # Copy the plist into place on every activation
  system.activationScripts.postActivation.text = ''
    echo "==> Deploying iTerm2 preferences..."
    mkdir -p "${prefsDir}"
    cp "${plistSrc}" "${prefsDir}/com.googlecode.iterm2.plist"
    chmod 644 "${prefsDir}/com.googlecode.iterm2.plist"
  '';
}
