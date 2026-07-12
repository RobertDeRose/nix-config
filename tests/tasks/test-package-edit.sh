#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
source "$ROOT/tests/tasks/_testlib.bash"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cp -R "$ROOT/.mise" "$ROOT/inventory.toml" "$ROOT/packages.toml" "$ROOT/mise.toml" "$tmp/"
make_git_repo "$tmp"
(
  cd "$tmp"
  usage_package=hello usage_profile=developer "$tmp/.mise/tasks/package/add"
)
python3 - "$tmp/packages.toml" <<'PY'
import sys, tomllib
with open(sys.argv[1], 'rb') as handle:
    data = tomllib.load(handle)
assert data['profiles']['developer']['nix']['packages'] == ['hello']
PY
before="$(cat "$tmp/packages.toml")"
if (
  cd "$tmp"
  usage_package=hello usage_profile=developer "$tmp/.mise/tasks/package/add"
) >/dev/null 2>&1; then
  fail 'package:add accepted a duplicate package'
fi
assert_eq "$before" "$(cat "$tmp/packages.toml")" 'failed package:add did not restore packages.toml'
