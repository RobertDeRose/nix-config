# modules/darwin/system.nix
# macOS-only system configuration (Dock, Finder, trackpad, fonts, etc.)
# All options: https://daiderd.com/nix-darwin/manual/index.html#sec-options
{
  pkgs,
  username,
  fullname,
  ...
}:
{
  imports = [ ../common/fonts.nix ];

  # Declare the primary user — nix-darwin needs this for system features,
  # and home-manager reads users.users.<name>.home for homeDirectory.
  system.primaryUser = username;
  users.users.${username} = {
    home = "/Users/${username}";
    description = fullname;
  };

  documentation = {
    enable = false;
    doc.enable = false;
    info.enable = false;
    man.enable = true;
  };

  environment.shells = [ pkgs.zsh ];

  # Required for nix-darwin's default shell
  programs.zsh.enable = true;

  # TouchID / WatchID for sudo
  security.pam.services.sudo_local = {
    reattach = true;
    touchIdAuth = true;
    watchIdAuth = true;
  };

  system = {
    defaults = {
      controlcenter.BatteryShowPercentage = true;

      CustomUserPreferences = {
        NSGlobalDomain.WebKitDeveloperExtras = true;
        "com.apple.desktopservices" = {
          DSDontWriteNetworkStores = true;
          DSDontWriteUSBStores = true;
        };
        "com.apple.AdLib".allowApplePersonalizedAdvertising = false;
        "com.apple.ImageCapture".disableHotPlug = true;
      };

      dock = {
        autohide = true;
        expose-group-apps = true;
        minimize-to-application = true;
        show-recents = false;
        showDesktopGestureEnabled = true;
        # Hot Corners
        wvous-bl-corner = 4; # Desktop
        wvous-br-corner = 6; # Disable Screen Saver
        wvous-tl-corner = 10; # Put Display to Sleep
        wvous-tr-corner = 14; # Quick Note
      };

      finder = {
        _FXEnableColumnAutoSizing = true;
        _FXShowPosixPathInTitle = true;
        _FXSortFoldersFirst = true;
        _FXSortFoldersFirstOnDesktop = true;
        AppleShowAllFiles = true;
        FXDefaultSearchScope = "SCcf";
        FXEnableExtensionChangeWarning = false;
        FXPreferredViewStyle = "Nlsv";
        FXRemoveOldTrashItems = true;
        NewWindowTarget = "Home";
        ShowMountedServersOnDesktop = true;
        ShowPathbar = true;
        ShowStatusBar = true;
      };

      trackpad = {
        Clicking = true;
        Dragging = true;
        TrackpadRightClick = true;
        TrackpadThreeFingerDrag = true;
      };

      NSGlobalDomain = {
        "com.apple.keyboard.fnState" = true;
        "com.apple.mouse.tapBehavior" = 1;
        "com.apple.sound.beep.feedback" = 0;
        "com.apple.swipescrolldirection" = false;
        AppleKeyboardUIMode = 2;
        AppleShowAllExtensions = true;
        AppleShowAllFiles = true;
        NSAutomaticCapitalizationEnabled = false;
        NSDocumentSaveNewDocumentsToCloud = false;
        NSNavPanelExpandedStateForSaveMode = true;
        NSNavPanelExpandedStateForSaveMode2 = true;
        NSTextShowsControlCharacters = true;
        NSWindowShouldDragOnGesture = true;
        PMPrintingExpandedStateForPrint = true;
        PMPrintingExpandedStateForPrint2 = true;
      };

      screencapture = {
        show-thumbnail = true;
        target = "clipboard";
        type = "png";
      };

      loginwindow.GuestEnabled = false;
    };

    keyboard = {
      enableKeyMapping = true;
      remapCapsLockToEscape = true;
    };

    stateVersion = 6;
  };

  time.timeZone = "America/New_York";
}
