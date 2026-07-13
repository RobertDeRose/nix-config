#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
source "$ROOT/tests/tasks/_testlib.bash"
source "$ROOT/.mise/lib/common.sh"
source "$ROOT/.mise/lib/inventory.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cat > "$tmp/inventory.toml" << 'TOML'
schema = 1
[defaults]
user = "alice"
[users.alice]
username = "alice"
full_name = "Alice Example"
email = "alice@example.invalid"
github = "alice-example"
[hosts.mac-one]
system = "aarch64-darwin"
profiles = ["base", "developer", "mac-desktop"]
[hosts.linux-one]
system = "x86_64-linux"
user = "alice"
profiles = ["base", "linux-server"]
[hosts.linux-one.features]
personal_cache = true
TOML

assert_eq $'linux-one\nmac-one' "$(inventory_hosts "$tmp")" 'inventory host list'
assert_eq aarch64-darwin "$(inventory_host_system "$tmp" mac-one)" 'host system'
assert_eq alice "$(inventory_host_user "$tmp" mac-one)" 'default user'
assert_eq $'base\ndeveloper\nmac-desktop' "$(inventory_host_profiles "$tmp" mac-one)" 'profile parsing'
assert_eq true "$(inventory_host_feature "$tmp" linux-one personal_cache)" 'feature parsing'
assert_success require_inventory_host "$tmp" mac-one
assert_failure require_inventory_host "$tmp" missing
assert_failure inventory_hosts "$tmp/missing"
