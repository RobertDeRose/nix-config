#!/usr/bin/env bash
# Prepare one-time user-state migrations before mise applies whole-file targets.
set -euo pipefail

backup_root="$HOME/.local/state/maison/backups"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"

# Git now reads its canonical configuration from ~/.config/git/config. A legacy
# ~/.gitconfig would take precedence over parts of that configuration, so retain
# it as an explicit migration backup instead of deleting it.
legacy_git="$HOME/.gitconfig"
if [ -e "$legacy_git" ] || [ -L "$legacy_git" ]; then
  mkdir -p "$backup_root/git"
  mv "$legacy_git" "$backup_root/git/gitconfig.$timestamp"
  printf 'Backed up legacy Git configuration to %s\n' "$backup_root/git/gitconfig.$timestamp"
fi
