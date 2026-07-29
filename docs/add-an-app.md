# Add a macOS application

Apple Silicon applications are declared in `config/mise/config.macos-arm64.toml`.

```bash
maison app add ghostty
maison user plan
maison user apply
```

`app add` installs the cask first and records it only after successful installation. Mac App Store entries use numeric `mas:` identifiers in the same file. System-wide fonts remain in `nix/modules/darwin/fonts.nix`. Casks that install OS integrations, such as FUSE-T, require an explicit nix-darwin module review instead of being added to the mise user package list.

Intel macOS is not a supported Maison target.
