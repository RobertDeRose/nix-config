#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
source "$ROOT/tests/tasks/_testlib.bash"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cp -R "$ROOT/.mise" "$ROOT/inventory.toml" "$tmp/"
mkdir -p "$tmp/deep/nested"
make_git_repo "$tmp"
output="$(cd "$tmp/deep/nested" && "$tmp/.mise/tasks/host/list")"
assert_contains "$output" USMBDEROSER 'nested invocation host list'
assert_contains "$output" dev-som 'nested invocation host list'
