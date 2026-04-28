#!/usr/bin/env bash
set -euo pipefail

SYSTEM="$1"
CACHE_NAME="$2"

if [ -z "${CACHIX_AUTH_TOKEN:-}" ]; then
  echo "Missing CACHIX_AUTH_TOKEN secret" >&2
  exit 1
fi

cachix authtoken "$CACHIX_AUTH_TOKEN"

build_target() {
  local target="$1"

  echo "==> Building ${target}"
  nix build --accept-flake-config --no-link --print-out-paths "$target" |
    cachix push "$CACHE_NAME"
}

case "$SYSTEM" in
  aarch64-darwin | x86_64-darwin | aarch64-linux | x86_64-linux)
    ;;

  *)
    echo "Unsupported system: $SYSTEM" >&2
    exit 1
    ;;
esac

build_count=0

for package in opencode openspec worktrunk system-manager; do
  target=".#packages.${SYSTEM}.${package}"

  if ! nix eval --raw "${target}.outPath" > /dev/null 2>&1; then
    echo "Skipping ${target} (not available)"
    continue
  fi

  build_target "$target"
  build_count=$((build_count + 1))
done

if [ "$build_count" -eq 0 ]; then
  echo "No cache refresh package targets available for $SYSTEM"
fi
