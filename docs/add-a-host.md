# Add a host

## 1. Select a system and profiles

Supported systems:

```text
aarch64-darwin
x86_64-darwin
aarch64-linux
x86_64-linux
```

Profiles:

- `base` and `dev` are cross-platform.
- `mac` is Darwin-only.
- `linux` is Linux-only.

## 2. Ensure the user exists

Users are declared once in `inventory.toml`:

```toml
[users.rderose]
username = "rderose"
full_name = "Robert DeRose"
email = "rderose@example.com"
github = "RobertDeRose"
```

Do not place secrets in the inventory. New usernames must be portable lowercase, non-root account names.

## 3. Add the host

```bash
mise run host:add build-server \
  --system x86_64-linux \
  --user rderose \
  --profiles base,dev,linux
```

For a new user, also provide `--fullname`, `--email`, and `--github`.

The command validates the hostname, system, user, profile names, and platform compatibility. It writes one inventory entry, validates the complete inventory, evaluates the new output when Nix is available, and shows a diff. It does not create/switch a branch, stage, commit, or push.

Use `--commit` only when an immediate local commit is intended. The command never pushes.

## 4. Add overrides only for exceptions

Most hosts need only the inventory entry. When a real exception exists:

```bash
mise run host:add special-mac \
  --system aarch64-darwin \
  --user rderose \
  --profiles base,dev,mac \
  --overrides
```

This creates:

```text
hosts/special-mac/system.nix
hosts/special-mac/home.nix
```

Remove an unused empty file. Do not repeat the system, user, or profile metadata in overrides.

## 5. Validate and preview

```bash
mise run host:validate
mise run check:hosts
mise run plan --host build-server
```

`plan --host` requires the selected host to match the current machine platform. Remote Linux hosts can be built and activated with:

```bash
mise run deploy user@destination build-server
```

## 6. Apply or bootstrap

On an already configured matching machine:

```bash
mise run apply --host build-server
```

On a fresh machine:

```bash
./bootstrap.sh --host build-server
```

Existing flake output names are generated automatically; `flake.nix` does not need a host-specific edit.
