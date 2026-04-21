# Per-Host Overrides

Every host can customize the global configuration without editing shared modules.
Nix's module system merges lists and attribute sets, so per-host files simply
*add* to what's already defined.

## What Can Be Overridden

### System-level (in `default.nix` or `system.nix`)

```nix
# Add Homebrew packages (macOS)
homebrew.brews = [ "mosquitto" ];
homebrew.casks = [ "slack" ];
homebrew.masApps = { "Xcode" = 497799835; };

# Add nix system packages
environment.systemPackages = with pkgs; [ terraform ];

# Change macOS defaults
system.defaults.dock.autohide = false;

# Enable the Apple container Linux builder
services.container-builder.enable = true;
```

### User-level (in `home.nix`)

```nix
{ pkgs, ... }:
{
  # Add user packages
  home.packages = with pkgs; [ spotify-player ];

  # Add shell aliases
  home.shellAliases = {
    work = "cd ~/workspace/work";
    personal = "cd ~/workspace/personal";
  };

  # Create files in $HOME
  home.file."workspace/personal/.gitconfig".text = ''
    [user]
      email = personal@example.com
  '';
}
```

## How It Works

The host's `default.nix` is imported as an additional module alongside the
global modules. Nix merges all option definitions:

- **Lists** (`homebrew.brews`, `home.packages`): concatenated
- **Attribute sets** (`home.shellAliases`): merged (host values override on conflict)
- **Scalars** (`system.defaults.dock.autohide`): last definition wins (use
  `lib.mkForce` if the global module also sets it)

## File Structure

```
hosts/aarch64-darwin/MYMACHINE/
├── default.nix     # System overrides (required)
├── user.nix        # Username + email (required)
└── home.nix        # Home-manager overrides (optional)
```

The `home.nix` is conditionally imported -- if the file doesn't exist, it's
skipped. No boilerplate needed.
