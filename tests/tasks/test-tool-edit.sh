#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
source "$ROOT/tests/tasks/_testlib.bash"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cp -R "$ROOT/.mise" "$ROOT/inventory.toml" "$ROOT/packages.toml" "$ROOT/mise.toml" "$tmp/"
make_git_repo "$tmp"
(
  cd "$tmp"
  usage_tool=node "$tmp/.mise/tasks/tool/remove" > /dev/null
)

(
  cd "$tmp"
  usage_tool=node@24 "$tmp/.mise/tasks/tool/add" > /dev/null
  usage_tool=node@lts "$tmp/.mise/tasks/tool/add" > /dev/null
)
python3 - "$tmp/mise.toml" << 'PY'
import sys, tomllib
with open(sys.argv[1], "rb") as handle:
    tools = tomllib.load(handle)["tools"]
assert tools["node"] == ["24", "lts"]
assert "node@24" not in tools
assert "node@lts" not in tools
PY

(
  cd "$tmp"
  usage_tool=node@24 "$tmp/.mise/tasks/tool/remove" > /dev/null
)
python3 - "$tmp/mise.toml" << 'PY'
import sys, tomllib
with open(sys.argv[1], "rb") as handle:
    tools = tomllib.load(handle)["tools"]
assert tools["node"] == "lts"
PY

(
  cd "$tmp"
  usage_tool=node "$tmp/.mise/tasks/tool/remove" > /dev/null
)
python3 - "$tmp/mise.toml" << 'PY'
import sys, tomllib
with open(sys.argv[1], "rb") as handle:
    tools = tomllib.load(handle)["tools"]
assert "node" not in tools
PY
