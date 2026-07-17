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

cat > "$tmp/bin/usage" << 'MOCK'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
  bash)
    shift
    exec bash "$@"
    ;;
  generate)
    printf 'usage-generate:%s\n' "$*"
    ;;
  *)
    exit 2
    ;;
esac
MOCK
chmod +x "$tmp/bin/usage"

cat > "$tmp/bin/mise" << 'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$MOCK_LOG/mise"
if [ "${MOCK_RATE_LIMIT:-0}" = 1 ]; then
  printf 'GitHub API returned 403 Forbidden: API rate limit exceeded\n'
fi
MOCK
chmod +x "$tmp/bin/mise"

HOME="$tmp/home" PATH="$tmp/bin:$PATH" MOCK_LOG="$tmp/log" MAISON_HOME="$tmp/home/.maison" \
  "$ROOT/bin/maison" apply --host test-host
assert_file_contains "$tmp/log/mise" 'run apply -- --host test-host'

HOME="$tmp/home" PATH="$tmp/bin:$PATH" MOCK_LOG="$tmp/log" MAISON_HOME="$tmp/home/.maison" \
  "$ROOT/bin/maison" help apply
assert_file_contains "$tmp/log/mise" 'run apply --help'

HOME="$tmp/home" PATH="$tmp/bin:$PATH" MOCK_LOG="$tmp/log" MAISON_HOME="$tmp/home/.maison" \
  "$ROOT/bin/maison" tasks
assert_file_contains "$tmp/log/mise" 'tasks'

assert_file_contains "$ROOT/bin/maison" '#!/usr/bin/env -S usage bash'
assert_file_contains "$ROOT/bin/maison" '#USAGE about "Put your workstation in order."'
assert_file_contains "$ROOT/bin/maison" '#USAGE cmd "github"'
assert_file_contains "$ROOT/bin/maison" 'NIX_CONFIG_DIR'
assert_file_contains "$ROOT/bin/maison" 'usage generate completion "$2" maison'
if grep -Fq -- 'completion-init' "$ROOT/bin/maison"; then
  fail 'Maison still uses the global Usage completion fallback'
fi

completion="$(HOME="$tmp/home" PATH="$tmp/bin:$PATH" MOCK_LOG="$tmp/log" MAISON_HOME="$tmp/home/.maison" \
  "$ROOT/bin/maison" completion bash)"
expected_completion="usage-generate:generate completion bash maison -f $tmp/home/.maison/bin/maison"
assert_eq "$expected_completion" "$completion" 'Maison per-command completion generation'

HOME="$tmp/home" PATH="$tmp/bin:$PATH" MOCK_LOG="$tmp/log" MAISON_HOME="$tmp/home/.maison" \
  "$ROOT/bin/maison" github auth
assert_file_contains "$tmp/log/mise" 'run --skip-tools github:auth --'

HOME="$tmp/home" PATH="$tmp/bin:$PATH" MOCK_LOG="$tmp/log" MAISON_HOME="$tmp/home/.maison" \
  "$ROOT/bin/maison" bootstrap --host test-host
assert_file_contains "$tmp/log/mise" 'run --skip-tools bootstrap -- --host test-host'

rate_limit_output="$(HOME="$tmp/home" PATH="$tmp/bin:$PATH" MOCK_LOG="$tmp/log" MOCK_RATE_LIMIT=1 MAISON_HOME="$tmp/home/.maison" \
  "$ROOT/bin/maison" apply 2>&1)"
printf '%s\n' "$rate_limit_output" | grep -Fq 'Run: maison github auth' || fail 'Maison did not report GitHub authentication recovery'
