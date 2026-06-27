# home/common/pi.nix
# Pi coding agent interface customization.
{
  lib,
  pkgs,
  inputs,
  ...
}:
let
  json = pkgs.formats.json { };
  piPackage = inputs.llmagents.packages.${pkgs.stdenv.hostPlatform.system}.pi;

  # Match the Ayu Mirage palette used by starship in home/common/shell.nix.
  ayuMirageTheme = {
    "$schema" =
      "https://raw.githubusercontent.com/earendil-works/pi/main/packages/coding-agent/src/modes/interactive/theme/theme-schema.json";
    name = "ayu-mirage";
    vars = {
      background = "#1F2430";
      black = "#191E2A";
      currentLine = "#44475A";
      foreground = "#CBCCC6";
      dim = "#707A8C";
      blue = "#73D0FF";
      brightBlue = "#59C2FF";
      cyan = "#95E6CB";
      green = "#AAD94C";
      lightGreen = "#D5FF80";
      purple = "#D4BFFF";
      red = "#F28779";
      orange = "#FFAD66";
      yellow = "#FFD173";
    };
    colors = {
      accent = "blue";
      border = "currentLine";
      borderAccent = "cyan";
      borderMuted = "dim";
      success = "green";
      error = "#FF6B5F";
      warning = "#FFB454";
      muted = "dim";
      dim = 240;
      text = "foreground";
      thinkingText = "dim";

      selectedBg = "#2A3140";
      userMessageBg = "#28384A";
      userMessageText = "#E6F4FF";
      customMessageBg = "#252B38";
      customMessageText = "foreground";
      customMessageLabel = "cyan";
      toolPendingBg = "#1A202B";
      toolSuccessBg = "#1B261D";
      toolErrorBg = "#2A1D20";
      toolTitle = "#5FAFD7";
      toolOutput = "#AEB6BF";

      mdHeading = "orange";
      mdLink = "blue";
      mdLinkUrl = "dim";
      mdCode = "cyan";
      mdCodeBlock = "foreground";
      mdCodeBlockBorder = "currentLine";
      mdQuote = "purple";
      mdQuoteBorder = "dim";
      mdHr = "currentLine";
      mdListBullet = "cyan";

      toolDiffAdded = "green";
      toolDiffRemoved = "red";
      toolDiffContext = "dim";

      syntaxComment = "dim";
      syntaxKeyword = "purple";
      syntaxFunction = "blue";
      syntaxVariable = "orange";
      syntaxString = "green";
      syntaxNumber = "yellow";
      syntaxType = "cyan";
      syntaxOperator = "purple";
      syntaxPunctuation = "dim";

      thinkingOff = "#3A4150";
      thinkingMinimal = "#5F87AF";
      thinkingLow = "#73D0FF";
      thinkingMedium = "#AAD94C";
      thinkingHigh = "#FFAD66";
      thinkingXhigh = "#FF4D6D";
      bashMode = "yellow";
    };
    export = {
      pageBg = "#191E2A";
      cardBg = "#1F2430";
      infoBg = "#252B38";
    };
  };
in
{
  home.packages = [ piPackage ];

  home.file.".pi/agent/themes/ayu-mirage.json".source =
    json.generate "pi-ayu-mirage-theme.json" ayuMirageTheme;
  home.file.".pi/agent/extensions/ayu-footer.ts".source = ../../files/pi/extensions/footer.ts;
  home.file.".pi/agent/extensions/markdown-pager.ts".source = ../../files/pi/extensions/pager.ts;
  home.file.".pi/agent/extensions/bookmark.ts".source = ../../files/pi/extensions/bookmark.ts;

  home.activation.removeOldPiOverlayExtension = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    rm -f "$HOME/.pi/agent/extensions/interface-overlays.ts"
  '';

  # Keep Pi settings mutable (Pi writes this file from /settings) while ensuring
  # our preferred interface defaults are applied after each home-manager switch.
  home.activation.configurePiInterface = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    settings_file="$HOME/.pi/agent/settings.json"
    mkdir -p "$(dirname "$settings_file")"

    if [ ! -s "$settings_file" ]; then
      printf '{}\n' > "$settings_file"
      chmod 600 "$settings_file"
    fi

    tmp_file="$(${pkgs.coreutils}/bin/mktemp)"
    if ${pkgs.jq}/bin/jq '. * {
      theme: "ayu-mirage",
      steeringMode: "one-at-a-time",
      transport: "auto",
      defaultProvider: "github-copilot",
      defaultModel: "gpt-5.5",
      defaultThinkingLevel: "low",
      terminal: {
        showTerminalProgress: true
      },
      enableInstallTelemetry: false,
      editorPaddingX: 1,
      autocompleteMaxVisible: 8,
      collapseChangelog: true
    }' "$settings_file" > "$tmp_file"; then
      mv "$tmp_file" "$settings_file"
      chmod 600 "$settings_file"
    else
      rm -f "$tmp_file"
      echo "warning: could not update Pi settings at $settings_file" >&2
    fi
  '';
}
