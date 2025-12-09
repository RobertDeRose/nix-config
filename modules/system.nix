{ pkgs, ... }:

  ###################################################################################
  #
  #  macOS's System configuration
  #
  #  All the configuration options are documented here:
  #    https://daiderd.com/nix-darwin/manual/index.html#sec-options
  #  Incomplete list of macOS `defaults` commands :
  #    https://github.com/yannbertrand/macos-defaults
  #
  ###################################################################################
{
  documentation = {
    enable = false;
    doc.enable = false;
    info.enable = false;
    man.enable = true;
  };

  environment = {
    shells = [
      pkgs.zsh
    ];
  };

  fonts.packages = with pkgs; [
    # icon fonts
    material-design-icons
    font-awesome

    # Nerd Fonts
    nerd-fonts.dejavu-sans-mono
    nerd-fonts.fira-code
    nerd-fonts.meslo-lg
    nerd-fonts.symbols-only
  ];

  # Create /etc/zshrc that loads the nix-darwin environment.
  # this is required if you want to use darwin's default shell - zsh
  programs.zsh.enable = true;

  # Add ability to used TouchID for sudo authentication
  security.pam.services.sudo_local = {
    reattach = true;
    touchIdAuth = true;
    watchIdAuth = true;
  };

  system = {
    defaults = {
      controlcenter.BatteryShowPercentage = true;

      # Customize settings that not supported by nix-darwin directly see the source code of this project to get more
      # undocumented options: https://github.com/rgcr/m-cli
      #
      # All entries can be found by running `defaults read` command. or `defaults read xxx` to read a specific domain.
      CustomUserPreferences = {
        NSGlobalDomain = {
          # Add a context menu item for showing the Web Inspector in web views
          WebKitDeveloperExtras = true;
        };
        "com.apple.desktopservices" = {
          # Avoid creating .DS_Store files on network or USB volumes
          DSDontWriteNetworkStores = true;
          DSDontWriteUSBStores = true;
        };
        "com.apple.screencapture" = {
          location = "~/Desktop";
          type = "png";
        };
        "com.apple.AdLib" = {
          allowApplePersonalizedAdvertising = false;
        };
        # Prevent Photos from opening automatically when devices are plugged in
        "com.apple.ImageCapture".disableHotPlug = true;
      };

      # customize dock
      dock = {
        autohide = true;
        expose-group-apps = true; # group windows by application in Mission Control’s Exposé
        minimize-to-application = true; # minimize windows into their application icon
        show-recents = true;
        showDesktopGestureEnabled = true; # enable four-finger spread gesture to show the Desktop

        # customize Hot Corners
        wvous-bl-corner = 4;    # Bottom - Left   - Desktop
        wvous-br-corner = 6;    # Bottom - Rifht  - Disable Screen Saver
        wvous-tl-corner = 10;   # Top - Left      - Put Display to Sleep
        wvous-tr-corner = 14;   # Top - Right     - Quick Note
      };

      # customize finder
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

      # customize trackpad
      trackpad = {
        Clicking = true;  # enable tap to click
        Dragging = true; # enable click to drag
        TrackpadRightClick = true;  # enable two finger right click
        TrackpadThreeFingerDrag = true;  # enable three finger drag
      };

      # customize settings that not supported by nix-darwin directly
      # Incomplete list of macOS `defaults` commands :
      #   https://github.com/yannbertrand/macos-defaults
      NSGlobalDomain = {
        "com.apple.keyboard.fnState" = true; # Use F1, F2, etc. keys as standard function keys.
        "com.apple.mouse.tapBehavior" = 1; # Configures the trackpad tap behavior. Mode 1 enables tap to click.
        "com.apple.sound.beep.feedback" = 0;  # disable beep sound when pressing volume up/down key
        "com.apple.swipescrolldirection" = false; # disable natural scrolling(default to true)
        AppleKeyboardUIMode = 2;  # Mode 2 enables full keyboard control on Sonoma or later
        AppleShowAllExtensions = true;
        AppleShowAllFiles = true;
        NSAutomaticCapitalizationEnabled = false;  # disable auto capitalization
        #NSAutomaticDashSubstitutionEnabled = false;  # disable auto dash substitution
        #NSAutomaticPeriodSubstitutionEnabled = false;  # disable auto period substitution
        #NSAutomaticQuoteSubstitutionEnabled = false;  # disable auto quote substitution
        #NSAutomaticSpellingCorrectionEnabled = false;  # disable auto spelling correction
        NSDocumentSaveNewDocumentsToCloud = false; # disable saving to iCloud by default
        NSNavPanelExpandedStateForSaveMode = true;  # expand save panel by default(保存文件时的路径选择/文件名输入页)
        NSNavPanelExpandedStateForSaveMode2 = true;
        NSTextShowsControlCharacters = true;
        NSWindowShouldDragOnGesture = true; # enable moving window by holding anywhere on it like on Linux
        PMPrintingExpandedStateForPrint = true; # expanded print panel by default
        PMPrintingExpandedStateForPrint2 = true;
      };

      screencapture = {
        show-thumbnail = true;
        target = "clipboard";
        type = "png";
      };

      loginwindow = {
        GuestEnabled = false;  # disable guest user
      };
    };

    # keyboard settings is not very useful on macOS
    keyboard = {
      enableKeyMapping = true;  # enable key mapping so that we can use `option` as `control`
      remapCapsLockToEscape  = true;   # remap caps lock to escape, useful for vim users
    };

    stateVersion = 6;
  };

  # Set your time zone.
  time.timeZone = "America/New_York";
}
