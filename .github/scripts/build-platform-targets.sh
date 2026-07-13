#!/usr/bin/env bash
set -euo pipefail

SYSTEM="${1:?usage: build-platform-targets.sh <nix-system>}"
REPO_ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
cd "$REPO_ROOT"

case "$SYSTEM" in
  aarch64-darwin | x86_64-darwin | aarch64-linux | x86_64-linux) ;;
  *)
    printf 'Unsupported system: %s\n' "$SYSTEM" >&2
    exit 1
    ;;
esac

build_target() {
  local target="$1"
  printf '==> Building %s\n' "$target"
  nix build --accept-flake-config --no-link "$target"
}

ensure_linux_user() {
  local username="$1" fullname="$2"
  id -u "$username" > /dev/null 2>&1 && return 0
  sudo useradd --create-home --comment "$fullname" --shell /bin/bash "$username"
}

ensure_darwin_user() {
  local username="$1" fullname="$2" next_uid
  id -u "$username" > /dev/null 2>&1 && return 0
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
  local username="$1" fullname="$2"
  case "$SYSTEM" in
    *-darwin) ensure_darwin_user "$username" "$fullname" ;;
    *-linux) ensure_linux_user "$username" "$fullname" ;;
  esac
}

host_rows() {
  python3 - "$SYSTEM" << 'PY'
import sys, tomllib
system = sys.argv[1]
with open("inventory.toml", "rb") as handle:
    inventory = tomllib.load(handle)
users = inventory.get("users", {})
default_user = inventory.get("defaults", {}).get("user")
for name, host in sorted(inventory.get("hosts", {}).items()):
    if host.get("system") != system:
        continue
    user_key = host.get("user", default_user)
    user = users[user_key]
    username = user.get("username", user_key)
    fullname = user["full_name"]
    print(f"{name}\t{username}\t{fullname}")
PY
}

package_names="$(nix eval --json ".#packages.\"$SYSTEM\"" --apply builtins.attrNames | jq -r '.[]')"
while IFS= read -r package; do
  [ -n "$package" ] || continue
  build_target ".#packages.\"$SYSTEM\".\"$package\""
done <<< "$package_names"

found=false
while IFS=$'\t' read -r host username fullname; do
  [ -n "$host" ] || continue
  found=true
  ensure_runner_user "$username" "$fullname"
  case "$SYSTEM" in
    *-darwin)
      build_target ".#darwinConfigurations.\"$host\".system"
      ;;
    *-linux)
      build_target ".#systemConfigs.\"$host\""
      build_target ".#homeConfigurations.\"$host\".activationPackage"
      ;;
  esac
done < <(host_rows)

if [ "$found" = false ]; then
  printf '==> No inventory hosts target %s; package outputs were still validated.\n' "$SYSTEM"
fi
