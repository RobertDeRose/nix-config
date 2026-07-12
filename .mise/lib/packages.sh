#!/usr/bin/env bash

mise_tool_exists() {
  local root="$1" tool="$2"
  awk -v tool="$tool" '
    /^\[tools\][[:space:]]*$/ { active=1; next }
    /^\[/ { active=0 }
    active {
      line=$0; sub(/[[:space:]]*#.*/, "", line)
      if (line ~ "^[[:space:]]*\"?" tool "\"?[[:space:]]*=") found=1
    }
    END { exit found ? 0 : 1 }
  ' "$root/mise.toml"
}

package_profile_exists() {
  local root="$1" profile="$2"
  [ -f "$root/packages.toml" ] && grep -Eq "^\[profiles\.${profile}(\.|\])" "$root/packages.toml"
}
