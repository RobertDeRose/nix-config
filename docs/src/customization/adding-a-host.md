# Adding a New Host

Adding a host requires **no `flake.nix` editing**. Drop a directory into the
right place and it's auto-discovered.

## Quick Way (mise task)

From any machine with mise installed:

```bash
mise add-host <hostname> [os] [arch]
```

- `os` accepts `darwin` or `linux` (defaults to current machine)
- `arch` accepts `aarch64` or `x86_64` (defaults to current machine)

This creates the host directory from the appropriate template, generates
`user.nix` from git config, creates a feature branch `host/<hostname>`, and
commits.

## Manual Way

### macOS Host

```bash
mkdir -p hosts/aarch64-darwin/<hostname>
cp templates/darwin/* hosts/aarch64-darwin/<hostname>/
```

Edit `user.nix` with the machine's username and email:

```nix
{
  username = "jdoe";
  email = "jdoe@example.com";
}
```

### Linux Host

```bash
mkdir -p systems/x86_64-linux/<hostname>
cp templates/linux/* systems/x86_64-linux/<hostname>/
```

Edit `user.nix` the same way.

## Testing

After creating the host directory:

```bash
# macOS -- build without activating
nix build .#darwinConfigurations.<hostname>.config.system.build.toplevel

# Linux system-manager
nix build .#systemManagerConfigurations.<hostname>.config.build.toplevel

# Linux home-manager
nix build .#homeConfigurations.<hostname>.activationPackage
```

## Activating

On the target machine:

```bash
# macOS
sudo darwin-rebuild switch --flake .

# Linux
sudo system-manager switch --flake .
home-manager switch --flake .#<hostname>
```

Or use the mise tasks which handle platform detection:

```bash
mise switch
```
