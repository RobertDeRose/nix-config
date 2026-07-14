#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
source "$ROOT/tests/tasks/_testlib.bash"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cp -R "$ROOT/.mise" "$ROOT/inventory.toml" "$ROOT/packages.toml" "$ROOT/mise.toml" "$tmp/"
mkdir -p "$tmp/bin"
cat > "$tmp/bin/nix" << 'MOCK'
#!/usr/bin/env bash
set -euo pipefail
while (( $# > 0 )); do
  case "$1" in
    --accept-flake-config | --no-warn-dirty | --show-trace | --verbose) shift ;;
    --extra-experimental-features) shift 2 ;;
    --option) shift 3 ;;
    *) break ;;
  esac
done
[ "$1" = eval ] && [ "$2" = --raw ] || exit 2
printf 'derivation\n'
MOCK
chmod +x "$tmp/bin/nix"
make_git_repo "$tmp"
(
  cd "$tmp"
  PATH="$tmp/bin:$PATH" usage_package=hello "$tmp/.mise/tasks/package/add" > /dev/null
)
(
  cd "$tmp"
  PATH="$tmp/bin:$PATH" usage_package=cowsay usage_profile=dev "$tmp/.mise/tasks/package/add" > /dev/null
)
python3 - "$tmp/packages.toml" << 'PY'
import sys, tomllib
with open(sys.argv[1], 'rb') as handle:
    data = tomllib.load(handle)
assert 'hello' in data['profiles']['base']['nix']['packages']
assert data['profiles']['dev']['nix']['packages'] == ['cowsay']
PY
before="$(cat "$tmp/packages.toml")"
if (
  cd "$tmp"
  PATH="$tmp/bin:$PATH" usage_package=hello "$tmp/.mise/tasks/package/add"
) > /dev/null 2>&1; then
  fail 'package:add accepted a duplicate package'
fi
assert_eq "$before" "$(cat "$tmp/packages.toml")" 'failed package:add did not restore packages.toml'
