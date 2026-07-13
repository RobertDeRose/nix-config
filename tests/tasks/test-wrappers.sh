#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
source "$ROOT/tests/tasks/_testlib.bash"

check_wrapper() {
  local file="$1" expected="$2"
  assert_file_contains "$file" '# [MISE] hide=true'
  assert_file_contains "$file" "$expected"
  lines="$(grep -Ev '^(#!|#|$|set -euo pipefail|TASK_FILE=|REPO_ROOT=|cd "[$]REPO_ROOT"$|exec mise run )' "$file" || true)"
  [ -z "$lines" ] || fail "compatibility wrapper contains business logic: ${file#"$ROOT"/}: $lines"
}

check_wrapper "$ROOT/.mise/tasks/nix/init" 'exec mise run bootstrap -- "$@"'
check_wrapper "$ROOT/.mise/tasks/nix/switch" 'exec mise run apply -- "$@"'
check_wrapper "$ROOT/.mise/tasks/nix/debug" 'exec mise run apply -- --debug "$@"'
check_wrapper "$ROOT/.mise/tasks/nix/dry-run" 'exec mise run plan -- "$@"'
check_wrapper "$ROOT/.mise/tasks/nix/deploy" 'exec mise run deploy -- "$@"'
check_wrapper "$ROOT/.mise/tasks/nix/up" 'exec mise run update -- "$@"'
check_wrapper "$ROOT/.mise/tasks/add-host" 'exec mise run host:add -- "$@"'

check_wrapper "$ROOT/.mise/tasks/activate" 'exec mise run apply -- "$@"'
