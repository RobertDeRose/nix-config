#!/usr/bin/env bash

mise_tool_exists() {
  local root="$1" tool="$2"
  python3 - "$root/mise.toml" "$tool" <<'PY'
import sys, tomllib
with open(sys.argv[1], "rb") as handle:
    tools = tomllib.load(handle).get("tools", {})
raise SystemExit(0 if sys.argv[2] in tools else 1)
PY
}

package_profile_exists() {
  case "$2" in
    base|developer|mac-desktop|linux-server) return 0 ;;
    *) return 1 ;;
  esac
}

config_editor() {
  local root="$1"
  shift
  require_command python3
  python3 "$root/.mise/lib/config_edit.py" --root "$root" "$@"
}

validate_package_inventory() {
  config_editor "$1" validate
}

validate_package_change() {
  local root="$1"
  validate_package_inventory "$root"
  if command -v nix >/dev/null 2>&1; then
    mise run check:hosts
  else
    log_warn "Nix/Lix is unavailable; package attribute evaluation was skipped"
  fi
}
