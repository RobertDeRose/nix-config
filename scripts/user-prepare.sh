#!/usr/bin/env bash
# Prepare one-time user-state migrations before mise applies whole-file targets.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
backup_root="$HOME/.local/state/maison/backups"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
force_dotfiles=false

while [ "$#" -gt 0 ]; do
  case "$1" in
    --force-dotfiles) force_dotfiles=true ;;
    *)
      printf 'usage: %s [--force-dotfiles]\n' "${0##*/}" >&2
      exit 2
      ;;
  esac
  shift
done

backup_conflicting_dotfiles() {
  local output_file status backup_dir conflict target relative backup count
  output_file="$(mktemp)"
  status=0

  if (
    cd "$root"
    mise bootstrap --only dotfiles --dry-run
  ) >"$output_file" 2>&1; then
    rm -f "$output_file"
    return 0
  else
    status=$?
  fi

  if ! grep -qF 'refusing to overwrite existing files' "$output_file"; then
    cat "$output_file" >&2
    rm -f "$output_file"
    return "$status"
  fi

  backup_dir="$backup_root/dotfiles/$timestamp"
  [ ! -e "$backup_dir" ] || backup_dir="$backup_dir.$$"
  count=0

  while IFS= read -r conflict; do
    case "$conflict" in
      "~/"*) target="$HOME/${conflict#\~/}" ;;
      "$HOME"/*) target="$conflict" ;;
      *)
        printf 'error: cannot back up unexpected dotfile target: %s\n' "$conflict" >&2
        rm -f "$output_file"
        return 1
        ;;
    esac

    if [ ! -e "$target" ] && [ ! -L "$target" ]; then
      continue
    fi

    relative="${target#"$HOME"/}"
    backup="$backup_dir/$relative"
    mkdir -p "$(dirname "$backup")"

    if [ -L "$target" ] && [ ! -e "$target" ]; then
      printf '%s\n' "$(readlink "$target")" >"$backup.broken-symlink-target"
    else
      cp -RLp "$target" "$backup"
    fi

    rm -rf "$target"
    count=$((count + 1))
    printf 'Backed up conflicting dotfile %s to %s\n' "$target" "$backup"
  done < <(
    awk '
      /refusing to overwrite existing files/ { conflicts = 1; next }
      conflicts && /^  / { sub(/^  /, ""); print; next }
      conflicts { exit }
    ' "$output_file"
  )

  if [ "$count" -eq 0 ]; then
    cat "$output_file" >&2
    rm -f "$output_file"
    return "$status"
  fi

  rm -f "$output_file"
  printf 'Dotfile migration backup: %s\n' "$backup_dir"
}

if [ "$force_dotfiles" = true ]; then
  backup_conflicting_dotfiles
fi

# Git now reads its canonical configuration from ~/.config/git/config. A legacy
# ~/.gitconfig would take precedence over parts of that configuration, so retain
# it as an explicit migration backup instead of deleting it.
legacy_git="$HOME/.gitconfig"
if [ -e "$legacy_git" ] || [ -L "$legacy_git" ]; then
  mkdir -p "$backup_root/git"
  mv "$legacy_git" "$backup_root/git/gitconfig.$timestamp"
  printf 'Backed up legacy Git configuration to %s\n' "$backup_root/git/gitconfig.$timestamp"
fi
