# Troubleshooting

## Common Issues

### `darwin-rebuild switch` fails on first run

On a freshly bootstrapped machine, the first `darwin-rebuild switch` may fail
with a conflict about `/etc/nix/nix.conf`. This happens because the Nix
installer created the file and nix-darwin wants to manage it.

**Fix**: Back up and remove the conflicting file, then retry:

```bash
sudo mv /etc/nix/nix.conf /etc/nix/nix.conf.bak
sudo darwin-rebuild switch --flake .
```

### iTerm2 preferences not applying

iTerm2 preferences are deployed from an exported binary plist in
`config/iterm2/`. If you make changes in iTerm2's UI, they won't persist
across rebuilds unless you re-export:

```bash
mise iterm:export
```

This copies the live preferences back to the repo. Commit the updated plist.

### Font names don't match after update

Nerd Fonts v3 changed font naming conventions. If your terminal or editor
shows a fallback font:

| Old name (v2) | New name (v3) |
|---------------|---------------|
| `MesloLGS NF` | `MesloLGS Nerd Font` |
| `MesloLGS-NF-Regular` | `MesloLGSNF-Regular` |

Check the font name in your app's config and update it to the v3 name.

### Linux builder VM won't start

If `launchctl kickstart` does nothing:

1. Check if the service is registered:
   ```bash
   sudo launchctl print system/org.nixos.linux-builder | head -5
   ```
2. If it shows "Could not find service", the plist isn't loaded. Run
   `darwin-rebuild switch` to register it.
3. If state is "not running", `kickstart` should start it. Check system logs:
   ```bash
   log show --predicate 'process == "launchd"' --last 1m | grep linux-builder
   ```

### `nix build` doesn't use the linux-builder

Nix prefers binary cache substitution over remote building. If the package
is already cached, the builder is never contacted. Force remote building with:

```bash
nix build <derivation> --max-jobs 0
```

### Bitwarden SSH agent not working

The SSH agent config expects Bitwarden Desktop (Mac App Store version) to be
running. The socket path is:

```
~/Library/Containers/com.bitwarden.desktop/Data/.bitwarden-ssh-agent.sock
```

If using the non-App Store version, the path will be different.

### `mas` (Mac App Store CLI) errors

The repo uses a patched `mas` 6.0.1 via an overlay in `modules/common/overlays.nix`.
If you see errors about Mac App Store apps failing to install, check that the
overlay is still working and that you're signed into the App Store.

### Sudo prompts during `darwin-rebuild switch`

`darwin-rebuild switch` requires root. Since the 25.05 nix-darwin release,
activation must be run as root:

```bash
sudo darwin-rebuild switch --flake .
```

The `mise switch` task handles this automatically.
