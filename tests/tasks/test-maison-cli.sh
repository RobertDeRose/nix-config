#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
source "$ROOT/tests/tasks/_testlib.bash"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/home/.maison/.mise/tasks" "$tmp/home/.local/bin" "$tmp/bin" "$tmp/log"
printf '[tools]\n' > "$tmp/home/.maison/mise.toml"
printf '{}\n' > "$tmp/home/.maison/flake.nix"
printf '#!/usr/bin/env bash\n' > "$tmp/home/.maison/.mise/tasks/apply"
printf '#!/usr/bin/env bash\n' > "$tmp/home/.maison/.mise/tasks/bootstrap"
mkdir -p "$tmp/home/.maison/.mise/tasks/github"
printf '#!/usr/bin/env bash\n' > "$tmp/home/.maison/.mise/tasks/github/auth"
chmod +x "$tmp/home/.maison/.mise/tasks/apply" "$tmp/home/.maison/.mise/tasks/bootstrap" "$tmp/home/.maison/.mise/tasks/github/auth"

cat > "$tmp/bin/mise" << 'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$MOCK_LOG/mise"
MOCK
chmod +x "$tmp/bin/mise"

HOME="$tmp/home" PATH="$tmp/bin:$PATH" MOCK_LOG="$tmp/log" MAISON_HOME="$tmp/home/.maison" \
  "$ROOT/bin/maison" apply --host test-host
assert_file_contains "$tmp/log/mise" 'run apply --host test-host'

HOME="$tmp/home" PATH="$tmp/bin:$PATH" MOCK_LOG="$tmp/log" MAISON_HOME="$tmp/home/.maison" \
  "$ROOT/bin/maison" help apply
assert_file_contains "$tmp/log/mise" 'run apply --help'

HOME="$tmp/home" PATH="$tmp/bin:$PATH" MOCK_LOG="$tmp/log" MAISON_HOME="$tmp/home/.maison" \
  "$ROOT/bin/maison" tasks
assert_file_contains "$tmp/log/mise" 'tasks'

assert_file_contains "$ROOT/bin/maison" '#USAGE about='
assert_file_contains "$ROOT/bin/maison" 'NIX_CONFIG_DIR'

completion="$(HOME="$tmp/home" PATH="$tmp/bin:$PATH" MOCK_LOG="$tmp/log" MAISON_HOME="$tmp/home/.maison" \
  "$ROOT/bin/maison" completion bash)"
case "$completion" in
  *'complete -F _maison_complete maison'*) ;;
  *) fail 'bash completion was not generated' ;;
esac

HOME="$tmp/home" PATH="$tmp/bin:$PATH" MOCK_LOG="$tmp/log" MAISON_HOME="$tmp/home/.maison" \
  "$ROOT/bin/maison" github auth
assert_file_contains "$tmp/log/mise" 'run --skip-tools github:auth --'

HOME="$tmp/home" PATH="$tmp/bin:$PATH" MOCK_LOG="$tmp/log" MAISON_HOME="$tmp/home/.maison" \
  "$ROOT/bin/maison" bootstrap --host test-host
assert_file_contains "$tmp/log/mise" 'run --skip-tools bootstrap -- --host test-host'
