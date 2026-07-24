# Add a macOS application

Apple Silicon applications are declared in `config/mise/config.macos-arm64.toml`.

```bash
maison app add ghostty
maison user plan
maison user apply
```

Mac App Store entries use numeric `mas:` identifiers in the same file. System-wide fonts remain in `nix/modules/darwin/fonts.nix`. Casks that install OS integrations, such as FUSE-T, require an explicit nix-darwin module review instead of being added to the mise user package list.

Mise's built-in Homebrew backend does not supply Intel macOS parity. Do not add an Intel host until its package fallback is explicit.
