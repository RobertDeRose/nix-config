#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

assert_contains() {
  local file="$1"
  local expected="$2"
  local label="$3"

  if ! grep -Fq -- "$expected" "$file"; then
    printf 'FAIL: %s does not contain: %s (%s)\n' "$file" "$expected" "$label" >&2
    exit 1
  fi
}

assert_contains "$ROOT/mise.toml" '"github:peterldowns/nix-search-cli" = "latest"' 'nix-search project tool'
assert_contains "$ROOT/.mise/tasks/package/search" 'command -v nix-search' 'nix-search availability check'
# shellcheck disable=SC2016
assert_contains "$ROOT/.mise/tasks/package/search" \
  'nix-search --channel unstable --max-results 40 --search "$query"' "bounded nixpkgs search"

if grep -Fq -- 'nix --quiet search nixpkgs' "$ROOT/.mise/tasks/package/search"; then
  printf 'FAIL: package search must not evaluate the full nixpkgs package set\n' >&2
  exit 1
fi
