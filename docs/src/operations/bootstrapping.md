# Bootstrapping

The root script establishes a machine's unmanaged prerequisites and then delegates to Maison:

```bash
./bootstrap.sh --host <hostname> --repo RobertDeRose/maison --ref main
```

On Linux, bootstrap installs prerequisites in this order:

1. Homebrew for Linux
2. mise
3. Nix/Lix
4. Maison host configuration and activation

Installing Homebrew before Home Manager prevents managed Git URL rewrites from affecting Homebrew's initial repository setup. The process is idempotent: existing installations are detected and reused. After the prerequisites are available, the script installs the Maison command, trusts `mise.toml`, and runs `maison bootstrap --host <hostname>`.
