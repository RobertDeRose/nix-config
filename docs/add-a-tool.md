# Add a tool

Search first:

```bash
maison package search <name>
```

Prefer a mise backend for versioned standalone tools. Add personal or site-specific tools in the private overlay's `config/mise/config.toml`; keep public Maison limited to reusable starter defaults.

```bash
maison tool add github:owner/repository latest
maison tool add npm:@scope/package latest
```

Use a bootstrap package for a Homebrew bottle or host-integrated package:

```bash
maison package add brew:tool --macos
```

Only add a package to Nix when system activation or a privileged service depends on it.
