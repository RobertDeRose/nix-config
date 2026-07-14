#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
source "$ROOT/tests/tasks/_testlib.bash"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cp -R "$ROOT/.mise" "$ROOT/inventory.toml" "$tmp/"
mkdir -p "$tmp/hosts" "$tmp/bin"
cat > "$tmp/bin/mise" << 'MOCK'
#!/usr/bin/env bash
set -euo pipefail
[ "$1" = run ] && [ "$2" = host:validate ] || { echo "unexpected mise call: $*" >&2; exit 2; }
if [ "${MOCK_VALIDATE_FAIL:-false}" = true ]; then
  exit 9
fi
exec bash "$MOCK_ROOT/.mise/tasks/host/validate"
MOCK
chmod +x "$tmp/bin/mise"
cat > "$tmp/bin/nix" << 'MOCK'
#!/usr/bin/env bash
set -euo pipefail

while (( $# > 0 )); do
  case "$1" in
    --accept-flake-config | --no-warn-dirty | --show-trace | --verbose)
      shift
      ;;
    --extra-experimental-features)
      shift 2
      ;;
    --option)
      shift 3
      ;;
    *)
      break
      ;;
  esac
done

[ "$1" = eval ] && [ "$2" = --raw ] || {
  printf 'unexpected nix call: %s\n' "$*" >&2
  exit 2
}
printf 'derivation\n'
MOCK
chmod +x "$tmp/bin/nix"
make_git_repo "$tmp"
branch_before="$(git -C "$tmp" branch --show-current)"
commits_before="$(git -C "$tmp" rev-list --count HEAD)"
(
  cd "$tmp/subdir" 2> /dev/null || mkdir -p "$tmp/subdir" && cd "$tmp/subdir"
  PATH="$tmp/bin:$PATH" MOCK_ROOT="$tmp" \
    usage_hostname=build-server usage_system=x86_64-linux usage_user=rderose \
    usage_profiles=base,dev,linux \
    "$tmp/.mise/tasks/host/add" > /dev/null
)
assert_file_contains "$tmp/inventory.toml" '[hosts.build-server]'
assert_eq "$branch_before" "$(git -C "$tmp" branch --show-current)" 'host:add branch mutation'
assert_eq "$commits_before" "$(git -C "$tmp" rev-list --count HEAD)" 'host:add commit mutation'
[ ! -d "$tmp/hosts/build-server" ] || fail 'host:add created overrides without --overrides'

before="$(cat "$tmp/inventory.toml")"
if (
  cd "$tmp"
  PATH="$tmp/bin:$PATH" MOCK_ROOT="$tmp" \
    usage_hostname=bad-profile usage_system=x86_64-linux usage_user=rderose \
    usage_profiles=base,mac \
    "$tmp/.mise/tasks/host/add"
) > /dev/null 2>&1; then
  fail 'host:add accepted a platform-incompatible profile'
fi
assert_eq "$before" "$(cat "$tmp/inventory.toml")" 'failed host:add changed inventory'

before="$(cat "$tmp/inventory.toml")"
if (
  cd "$tmp"
  PATH="$tmp/bin:$PATH" MOCK_ROOT="$tmp" MOCK_VALIDATE_FAIL=true \
    usage_hostname=validation-fails usage_system=x86_64-linux usage_user=rderose \
    usage_profiles=base,linux \
    "$tmp/.mise/tasks/host/add"
) > /dev/null 2>&1; then
  fail 'host:add accepted a failed post-write validation'
fi
assert_eq "$before" "$(cat "$tmp/inventory.toml")" 'host:add did not restore inventory after validation failure'
