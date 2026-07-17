#!/usr/bin/env bash
set -euo pipefail
repo_root="$(git rev-parse --show-toplevel)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/home/.maison/.mise/tasks/package" "$tmp/bin"
cp "$repo_root/bin/maison" "$tmp/home/.maison/maison"
touch "$tmp/home/.maison/mise.toml" "$tmp/home/.maison/flake.nix"
printf '#!/usr/bin/env bash\n' > "$tmp/home/.maison/.mise/tasks/package/search"
chmod +x "$tmp/home/.maison/.mise/tasks/package/search"
cat > "$tmp/bin/mise" << 'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$*" > "$MOCK_LOG"
MOCK
chmod +x "$tmp/bin/mise"
MOCK_LOG="$tmp/log" HOME="$tmp/home" PATH="$tmp/bin:$PATH" "$tmp/home/.maison/maison" package search ripgrep
[ "$(cat "$tmp/log")" = 'run package:search -- ripgrep' ]
