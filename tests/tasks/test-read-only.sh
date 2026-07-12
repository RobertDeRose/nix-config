#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
source "$ROOT/tests/tasks/_testlib.bash"

for task in plan doctor check/_default check/shell check/nix check/inventory check/packages check/hosts check/tests; do
  file="$ROOT/.mise/tasks/$task"
  if grep -Eq '(^|[[:space:]])sudo([[:space:]]|$)|activate_host|darwin-rebuild[[:space:]]+switch|system-manager[[:space:]]+switch' "$file"; then
    fail "read-only task contains activation or sudo logic: $task"
  fi
done
