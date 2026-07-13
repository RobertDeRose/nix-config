#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
source "$ROOT/tests/tasks/_testlib.bash"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cp -R "$ROOT/.mise" "$tmp/"
printf '{"lock":"original"}\n' > "$tmp/flake.lock"
mkdir -p "$tmp/bin" "$tmp/log"

cat > "$tmp/bin/nix" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$MOCK_LOG/nix"
printf '{"lock":"candidate"}\n' > "$PWD/flake.lock"
if [ "${MOCK_NIX_FAIL:-false}" = true ]; then
  exit 7
fi
MOCK

cat > "$tmp/bin/mise" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf 'args=%s suppress_dirty=%s\n' "$*" "${NIX_SUPPRESS_DIRTY_WARNING:-false}" >> "$MOCK_LOG/mise"
[ "$1" = run ] && [ "$2" = check:hosts ] || exit 2
if [ "${MOCK_CHECK_FAIL:-false}" = true ]; then
  exit 9
fi
MOCK
chmod +x "$tmp/bin/"*
make_git_repo "$tmp"
original="$(cat "$tmp/flake.lock")"

if (
  cd "$tmp"
  PATH="$tmp/bin:$PATH" MOCK_LOG="$tmp/log" MOCK_NIX_FAIL=true \
    "$tmp/.mise/tasks/update"
) >"$tmp/update-failure.out" 2>&1; then
  fail 'update succeeded after the Nix update command failed'
fi
assert_eq "$original" "$(cat "$tmp/flake.lock")" 'failed Nix update did not restore flake.lock'
assert_file_contains "$tmp/update-failure.out" 'flake input update failed; restored the previous flake.lock'

: > "$tmp/log/nix"
: > "$tmp/log/mise"
if (
  cd "$tmp"
  PATH="$tmp/bin:$PATH" MOCK_LOG="$tmp/log" MOCK_CHECK_FAIL=true \
    "$tmp/.mise/tasks/update"
) >"$tmp/validation-failure.out" 2>&1; then
  fail 'update succeeded after host validation failed'
fi
assert_eq "$original" "$(cat "$tmp/flake.lock")" 'failed host validation did not restore flake.lock'
assert_file_contains "$tmp/validation-failure.out" 'host validation failed; restored the previous flake.lock'
assert_file_contains "$tmp/log/nix" '--option fallback true'
assert_file_contains "$tmp/log/nix" '--no-warn-dirty'
assert_file_contains "$tmp/log/mise" 'args=run check:hosts suppress_dirty=true'

: > "$tmp/log/nix"
: > "$tmp/log/mise"
(
  cd "$tmp"
  PATH="$tmp/bin:$PATH" MOCK_LOG="$tmp/log" \
    "$tmp/.mise/tasks/update"
) >"$tmp/success.out" 2>&1
assert_eq '{"lock":"candidate"}' "$(cat "$tmp/flake.lock")" 'successful update did not retain the candidate lockfile'
assert_file_contains "$tmp/success.out" 'Updated flake.lock and validated every configured host'
