#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
source "$ROOT/tests/tasks/_testlib.bash"

while IFS= read -r task; do
  relative_task="${task#"$ROOT"/}"
  [ -x "$task" ] || fail "file task is not executable: $relative_task"
  assert_eq '#!/usr/bin/env bash' "$(head -n1 "$task")" "task shebang for $relative_task"
  grep -Eq '^# \[MISE\] description="[^"]+"$' "$task" || fail "missing task description: $relative_task"
  # The expected text is literal shell source, not an expression to expand.
  # shellcheck disable=SC2016
  {
    assert_file_contains "$task" 'TASK_FILE="${BASH_SOURCE[0]}"'
    assert_file_contains "$task" 'REPO_ROOT="$(git -C "$(dirname "$TASK_FILE")" rev-parse --show-toplevel)"'
    assert_file_contains "$task" 'cd "$REPO_ROOT"'
  }
  if grep -q 'usage_' "$task"; then
    grep -q '^#USAGE ' "$task" || fail "argument-bearing task lacks #USAGE metadata: $relative_task"
  fi
  if grep -Eq '^#USAGE .*([=[:space:]])(true|false)([[:space:]]|$)' "$task"; then
    fail "KDL booleans in #USAGE metadata must use #true or #false: $relative_task"
  fi
done < <(find "$ROOT/.mise/tasks" -type f | sort)

assert_file_contains "$ROOT/mise.toml" 'includes = [".mise/tasks"]'
if grep -Eq '^\[tasks\.' "$ROOT/mise.toml"; then
  fail 'mise.toml still contains inline task definitions'
fi
