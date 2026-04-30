#!/usr/bin/env bash
set -euo pipefail

SYSTEM="$1"

build_target() {
  local target="$1"

  echo "==> Building ${target}"
  nix build --accept-flake-config --no-link "$target"
}

collect_hosts() {
  local dir="$1"

  if [ ! -d "$dir" ]; then
    return 0
  fi

  for path in "$dir"/*; do
    [ -d "$path" ] || continue
    basename "$path"
  done | sort
}

read_hosts() {
  local dir="$1"
  local host

  hosts=()
  while IFS= read -r host; do
    [ -n "$host" ] || continue
    hosts+=("$host")
  done < <(collect_hosts "$dir")
}

read_user_field() {
  local host_dir="$1"
  local field="$2"
  local user_file="$PWD/$host_dir/user.nix"

  [ -f "$user_file" ] || return 1

  nix eval --impure --raw --expr \
    "let user = import (builtins.toPath \"$user_file\"); in user.${field}"
}

ensure_linux_user() {
  local username="$1"
  local fullname="$2"

  if id -u "$username" > /dev/null 2>&1; then
    return 0
  fi

  sudo useradd --create-home --comment "$fullname" --shell /bin/bash "$username"
}

ensure_darwin_user() {
  local username="$1"
  local fullname="$2"
  local next_uid

  if id -u "$username" > /dev/null 2>&1; then
    return 0
  fi

  next_uid="$(dscl . -list /Users UniqueID | awk 'BEGIN { max = 500 } { if ($2 > max) max = $2 } END { print max + 1 }')"

  sudo dscl . -create "/Users/$username"
  sudo dscl . -create "/Users/$username" UserShell /bin/zsh
  sudo dscl . -create "/Users/$username" RealName "$fullname"
  sudo dscl . -create "/Users/$username" UniqueID "$next_uid"
  sudo dscl . -create "/Users/$username" PrimaryGroupID 20
  sudo dscl . -create "/Users/$username" NFSHomeDirectory "/Users/$username"
  sudo createhomedir -c -u "$username" > /dev/null 2>&1 || true
}

ensure_runner_user() {
  local username="$1"
  local fullname="$2"

  [ -n "$username" ] || return 0

  case "$(uname -s)" in
    Darwin)
      ensure_darwin_user "$username" "$fullname"
      ;;

    Linux)
      ensure_linux_user "$username" "$fullname"
      ;;
  esac
}

prepare_host_user() {
  local host_dir="$1"
  local username fullname

  username="$(read_user_field "$host_dir" username 2> /dev/null || true)"
  fullname="$(read_user_field "$host_dir" fullname 2> /dev/null || true)"

  if [ -n "$username" ]; then
    ensure_runner_user "$username" "${fullname:-$username}"
  fi
}

generate_host() {
  local os hostname user fullname email github_username host_dir

  os="${SYSTEM#*-}"
  hostname="cache-refresh-${SYSTEM//_/-}"
  user="$(whoami)"
  fullname="${CACHE_REFRESH_FULLNAME:-CI User}"
  email="${CACHE_REFRESH_EMAIL:-ci@localhost}"
  github_username="${CACHE_REFRESH_GITHUB_USERNAME:-RobertDeRose}"
  host_dir="$([ "$os" = "darwin" ] && printf 'hosts/%s/%s' "$SYSTEM" "$hostname" || printf 'systems/%s/%s' "$SYSTEM" "$hostname")"

  echo "No hosts found for ${SYSTEM}; generating ${hostname}" >&2

  mkdir -p "$host_dir"
  cp -R "templates/${os}/." "$host_dir/"

  cat > "$host_dir/user.nix" << EOF
{
  username = "$user";
  fullname = "$fullname";
  useremail = "$email";
  githubUsername = "$github_username";
}
EOF

  git add "$host_dir"

  printf '%s\n' "$hostname"
}

case "$SYSTEM" in
  aarch64-darwin | x86_64-darwin | aarch64-linux | x86_64-linux)
    ;;

  *)
    echo "Unsupported system: $SYSTEM" >&2
    exit 1
    ;;
esac

case "$SYSTEM" in
  aarch64-darwin | x86_64-darwin)
    read_hosts "hosts/$SYSTEM"

    if [ "${#hosts[@]}" -eq 0 ]; then
      hosts=("$(generate_host)")
    fi

    for host in "${hosts[@]}"; do
      prepare_host_user "hosts/$SYSTEM/$host"
      build_target ".#darwinConfigurations.${host}.system"
    done
    ;;

  aarch64-linux | x86_64-linux)
    read_hosts "systems/$SYSTEM"

    if [ "${#hosts[@]}" -eq 0 ]; then
      hosts=("$(generate_host)")
    fi

    for host in "${hosts[@]}"; do
      prepare_host_user "systems/$SYSTEM/$host"
      build_target ".#systemConfigs.${host}"
      build_target ".#homeConfigurations.${host}.activationPackage"
    done
    ;;
esac
