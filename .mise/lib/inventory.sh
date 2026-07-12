#!/usr/bin/env bash

inventory_path() {
  local root="$1"
  printf '%s/inventory.toml\n' "$root"
}

validate_hostname() {
  printf '%s' "$1" | grep -Eq '^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?$'
}

validate_username() {
  [ "$1" != root ] && printf '%s' "$1" | grep -Eq '^[a-z_][a-z0-9_-]*$'
}

validate_github_username() {
  printf '%s' "$1" | grep -Eq '^[A-Za-z0-9]([A-Za-z0-9-]{0,37}[A-Za-z0-9])?$'
}

inventory_field() {
  local file="$1" section="$2" key="$3"
  awk -v wanted="[$section]" -v wanted_key="$key" '
    function trim(s) { sub(/^[[:space:]]+/, "", s); sub(/[[:space:]]+$/, "", s); return s }
    /^[[:space:]]*\[/ {
      line=$0; sub(/[[:space:]]*#.*/, "", line); active=(trim(line)==wanted); next
    }
    active {
      line=$0
      sub(/[[:space:]]*#.*/, "", line)
      pos=index(line, "=")
      if (!pos) next
      lhs=trim(substr(line, 1, pos-1))
      if (lhs != wanted_key) next
      value=trim(substr(line, pos+1))
      if (value ~ /^".*"$/) value=substr(value, 2, length(value)-2)
      print value
      exit
    }
  ' "$file"
}

inventory_hosts() {
  local root="$1" file
  file="$(inventory_path "$root")"
  if [ -f "$file" ]; then
    awk '
      /^[[:space:]]*\[hosts\.[^]]+\][[:space:]]*$/ {
        line=$0
        sub(/^[[:space:]]*\[hosts\./, "", line)
        sub(/\][[:space:]]*$/, "", line)
        print line
      }
    ' "$file" | sort
    return
  fi

  find "$root/hosts" "$root/systems" -mindepth 2 -maxdepth 2 -type d 2>/dev/null \
    | awk -F/ '{ print $NF }' | sort -u
}

inventory_has_host() {
  local root="$1" host="$2"
  inventory_hosts "$root" | grep -Fxq "$host"
}

legacy_host_dir() {
  local root="$1" host="$2" match="" count=0 path
  for path in "$root"/hosts/*-darwin/"$host" "$root"/systems/*-linux/"$host"; do
    [ -d "$path" ] || continue
    match="$path"
    count=$((count + 1))
  done
  [ "$count" -eq 1 ] || return 1
  printf '%s\n' "$match"
}

inventory_host_system() {
  local root="$1" host="$2" file dir parent
  file="$(inventory_path "$root")"
  if [ -f "$file" ]; then
    inventory_field "$file" "hosts.$host" system
    return
  fi
  dir="$(legacy_host_dir "$root" "$host")" || return 1
  parent="$(basename "$(dirname "$dir")")"
  printf '%s\n' "$parent"
}

inventory_host_user() {
  local root="$1" host="$2" file dir user_file user
  file="$(inventory_path "$root")"
  if [ -f "$file" ]; then
    user="$(inventory_field "$file" "hosts.$host" user)"
    if [ -z "$user" ]; then
      user="$(inventory_field "$file" defaults user)"
    fi
    printf '%s\n' "$user"
    return
  fi
  dir="$(legacy_host_dir "$root" "$host")" || return 1
  user_file="$dir/user.nix"
  [ -f "$user_file" ] || return 1
  sed -n 's/^[[:space:]]*username[[:space:]]*=[[:space:]]*"\([^"]*\)";.*/\1/p' "$user_file" | head -n 1
}

inventory_host_profiles() {
  local root="$1" host="$2" file value
  file="$(inventory_path "$root")"
  [ -f "$file" ] || return 0
  value="$(inventory_field "$file" "hosts.$host" profiles)"
  printf '%s' "$value" | tr -d '[]"' | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sed '/^$/d'
}

inventory_user_field() {
  local root="$1" username="$2" field="$3" file dir user_file nix_field
  file="$(inventory_path "$root")"
  if [ -f "$file" ]; then
    inventory_field "$file" "users.$username" "$field"
    return
  fi
  for dir in "$root"/hosts/*-darwin/* "$root"/systems/*-linux/*; do
    [ -f "$dir/user.nix" ] || continue
    if [ "$(sed -n 's/^[[:space:]]*username[[:space:]]*=[[:space:]]*"\([^"]*\)";.*/\1/p' "$dir/user.nix" | head -n1)" = "$username" ]; then
      user_file="$dir/user.nix"
      case "$field" in
        username) nix_field=username ;;
        full_name) nix_field=fullname ;;
        email) nix_field=useremail ;;
        github) nix_field=githubUsername ;;
        *) return 1 ;;
      esac
      sed -n "s/^[[:space:]]*$nix_field[[:space:]]*=[[:space:]]*\"\\([^\"]*\\)\";.*/\\1/p" "$user_file" | head -n1
      return
    fi
  done
  return 1
}

host_platform_class() {
  case "$(inventory_host_system "$1" "$2")" in
    *-darwin) printf '%s\n' darwin ;;
    *-linux) printf '%s\n' linux ;;
    *) return 1 ;;
  esac
}

print_available_hosts() {
  local root="$1"
  printf 'Available hosts:\n' >&2
  inventory_hosts "$root" | sed 's/^/  /' >&2
}

require_inventory_host() {
  local root="$1" host="$2"
  if ! inventory_has_host "$root" "$host"; then
    printf 'Host "%s" is not defined in inventory.toml.\n\n' "$host" >&2
    print_available_hosts "$root"
    return 1
  fi
}

validate_host_platform() {
  local root="$1" host="$2" actual="$3" expected
  expected="$(inventory_host_system "$root" "$host")" || return 1
  if [ "$expected" != "$actual" ]; then
    printf 'Host "%s" is configured as %s, but this machine is %s.\n\n' "$host" "$expected" "$actual" >&2
    printf 'Use --host to select another configuration or correct inventory.toml.\n' >&2
    return 1
  fi
}

inventory_users() {
  local root="$1" file
  file="$(inventory_path "$root")"
  [ -f "$file" ] || return 0
  awk '
    /^[[:space:]]*\[users\.[^]]+\][[:space:]]*$/ {
      line=$0
      sub(/^[[:space:]]*\[users\./, "", line)
      sub(/\][[:space:]]*$/, "", line)
      print line
    }
  ' "$file" | sort
}

inventory_has_user() {
  local root="$1" user="$2"
  inventory_users "$root" | grep -Fxq "$user"
}

inventory_host_username() {
  local root="$1" host="$2" user username
  user="$(inventory_host_user "$root" "$host")" || return 1
  username="$(inventory_user_field "$root" "$user" username)"
  [ -n "$username" ] || username="$user"
  printf '%s\n' "$username"
}

inventory_user_allowed_for_system() {
  local root="$1" user="$2" system="$3" username allow_nonportable
  inventory_has_user "$root" "$user" || return 1
  username="$(inventory_user_field "$root" "$user" username)"
  [ -n "$username" ] || username="$user"
  [ "$username" != root ] || return 1
  if validate_username "$username"; then
    return 0
  fi
  allow_nonportable="$(inventory_user_field "$root" "$user" allow_nonportable)"
  [ "$allow_nonportable" = true ] || return 1
  case "$system" in
    *-darwin) return 0 ;;
    *) return 1 ;;
  esac
}

require_inventory_user_for_host() {
  local root="$1" host="$2" user system username
  user="$(inventory_host_user "$root" "$host")" || return 1
  system="$(inventory_host_system "$root" "$host")" || return 1
  if ! inventory_has_user "$root" "$user"; then
    die "host '$host' references missing user '$user'"
    return 1
  fi
  username="$(inventory_host_username "$root" "$host")" || return 1
  if ! inventory_user_allowed_for_system "$root" "$user" "$system"; then
    die "host '$host' has invalid managed username '$username' for system '$system'"
    return 1
  fi
  printf '%s\n' "$username"
}
