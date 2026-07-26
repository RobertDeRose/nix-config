#!/usr/bin/env bash
# Link the repository lockfile outside mise dotfile processing.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
dry_run=false

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run) dry_run=true ;;
    *)
      printf 'usage: %s [--dry-run]\n' "${0##*/}" >&2
      exit 2
      ;;
  esac
  shift
done

source="$root/config/mise/mise.lock"
target="$HOME/.config/mise/mise.lock"

if [ "$dry_run" = true ]; then
  printf 'ln -sfn %q %q\n' "$source" "$target"
  exit 0
fi

mkdir -p "$(dirname "$target")"
ln -sfn "$source" "$target"
