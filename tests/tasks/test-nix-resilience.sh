#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
source "$ROOT/tests/tasks/_testlib.bash"
source "$ROOT/.mise/lib/common.sh"
source "$ROOT/.mise/lib/inventory.sh"
source "$ROOT/.mise/lib/nix.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cat > "$tmp/inventory.toml" << 'TOML'
schema = 1
[users.alice]
full_name = "Alice"
email = "alice@example.invalid"
github = "alice"
[hosts.linux-one]
system = "x86_64-linux"
user = "alice"
profiles = ["base", "linux-server"]
TOML

nix_command() {
  printf '%s\n' "$*" >> "$tmp/calls"
  case "$*" in
    *'#systemConfigs."linux-one".type'*)
      [ "${MOCK_SYSTEM_FAIL:-false}" != true ] || return 17
      ;;
    *'#homeConfigurations."linux-one".activationPackage.type'*)
      [ "${MOCK_HOME_WRONG_TYPE:-false}" != true ] || {
        printf 'set\n'
        return 0
      }
      ;;
  esac
  printf 'derivation\n'
}

: > "$tmp/calls"
MOCK_SYSTEM_FAIL=true
assert_failure evaluate_host "$tmp" linux-one false
unset MOCK_SYSTEM_FAIL
assert_eq 1 "$(wc -l < "$tmp/calls" | tr -d ' ')" 'Linux evaluation continued after the system target failed'
assert_file_contains "$tmp/calls" '--option substituters https://cache.nixos.org'

: > "$tmp/calls"
assert_success evaluate_host "$tmp" linux-one false
assert_eq 2 "$(wc -l < "$tmp/calls" | tr -d ' ')" 'Linux evaluation did not check both outputs'

: > "$tmp/calls"
MOCK_HOME_WRONG_TYPE=true
assert_failure evaluate_host "$tmp" linux-one false
unset MOCK_HOME_WRONG_TYPE

flags=()
mapfile -t flags < <(nix_common_flags false)
assert_array_contains '--option' 'Nix common flags' "${flags[@]}"
assert_array_contains 'fallback' 'Nix common flags' "${flags[@]}"
NIX_SUPPRESS_DIRTY_WARNING=true
mapfile -t flags < <(nix_common_flags false)
unset NIX_SUPPRESS_DIRTY_WARNING
assert_array_contains '--no-warn-dirty' 'Nix dirty-warning suppression' "${flags[@]}"
