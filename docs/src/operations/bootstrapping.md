# Bootstrapping

The root script handles only pre-mise work and then delegates:

```bash
./bootstrap.sh --host <hostname> --repo RobertDeRose/nix-config --ref main
```

It installs minimal prerequisites, clones or enters the repository, installs mise, trusts `mise.toml`, and runs `mise run bootstrap --host <hostname>`. The mise task validates or creates the inventory entry, installs the platform-selected Nix/Lix implementation, builds, and applies the host.
