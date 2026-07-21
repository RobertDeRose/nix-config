#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
# shellcheck source=tests/tasks/_testlib.bash
source "$ROOT/tests/tasks/_testlib.bash"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
repo="$tmp/source-checkout"
home="$tmp/home"
mkdir -p "$repo/bin" "$repo/.mise/tasks" "$home/.local/bin" "$tmp/bin" "$tmp/log"
cp "$ROOT/bin/maison" "$repo/bin/maison"
chmod +x "$repo/bin/maison"
printf '[tools]\nusage = "latest"\n' > "$repo/mise.toml"
printf '{}\n' > "$repo/flake.nix"
printf '#!/usr/bin/env bash\n' > "$repo/.mise/tasks/apply"
chmod +x "$repo/.mise/tasks/apply"

cat > "$tmp/bin/usage" << 'MOCK'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
  bash)
    shift
    exec bash "$@"
    ;;
  *) exit 2 ;;
esac
MOCK
chmod +x "$tmp/bin/usage"

cat > "$tmp/bin/mise" << 'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$PWD" > "$MOCK_LOG/pwd"
printf '%s\n' "$*" > "$MOCK_LOG/args"
MOCK
chmod +x "$tmp/bin/mise"

ln -s "$repo/bin/maison" "$home/.local/bin/maison"
HOME="$home" PATH="$tmp/bin:$home/.local/bin:$PATH" MOCK_LOG="$tmp/log" \
  "$home/.local/bin/maison" tasks
expected_repo="$(cd "$repo" && pwd -P)"
resolved_repo="$(cat "$tmp/log/pwd")"
actual_repo="$(cd "$resolved_repo" && pwd -P)"
assert_eq "$expected_repo" "$actual_repo" 'Maison checkout resolved through launcher symlink'
assert_eq 'tasks' "$(cat "$tmp/log/args")" 'Maison task dispatch through launcher symlink'

# Intentional literal shell source patterns.
# shellcheck disable=SC2016
assert_file_contains "$ROOT/.mise/tasks/apply" 'usage_bin="$(mise -C "$REPO_ROOT" which usage'
# shellcheck disable=SC2016
assert_file_contains "$ROOT/.mise/tasks/apply" 'ln -sfn "$usage_bin" "$HOME/.local/bin/usage"'
# shellcheck disable=SC2016
assert_file_contains "$ROOT/.mise/tasks/apply" 'ln -sfn "$REPO_ROOT/bin/maison" "$HOME/.local/bin/maison"'
