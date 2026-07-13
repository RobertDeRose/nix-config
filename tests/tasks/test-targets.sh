#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
source "$ROOT/tests/tasks/_testlib.bash"
source "$ROOT/.mise/lib/common.sh"
source "$ROOT/.mise/lib/inventory.sh"
source "$ROOT/.mise/lib/nix.sh"

assert_eq '/repo#darwinConfigurations."mac-one".system' "$(darwin_target_for_host /repo mac-one)" 'Darwin target'
assert_eq '/repo#systemConfigs."linux-one"' "$(linux_system_target_for_host /repo linux-one)" 'Linux system target'
assert_eq '/repo#homeConfigurations."linux-one".activationPackage' "$(linux_home_target_for_host /repo linux-one)" 'Linux home target'

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cat > "$tmp/inventory.toml" << 'TOML'
schema = 1
[users.alice]
full_name = "Alice"
email = "alice@example.invalid"
github = "alice"
[hosts.build-server]
system = "x86_64-linux"
user = "alice"
profiles = ["base", "linux-server"]
TOML
assert_eq "$tmp#systemConfigs.\"build-server\"" "$(resolved_target_for_host "$tmp" build-server)" 'resolved Linux target'
