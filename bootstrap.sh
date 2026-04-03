#!/usr/bin/env bash
# bootstrap.sh — Install mise on a new machine, then hand off to mise.
# Usage: ./bootstrap.sh <hostname>
set -euo pipefail

if [[ -z "${1:-}" ]]; then
	echo "Usage: $0 <hostname>"
	echo "Example: $0 rderose-mbp"
	exit 1
fi

HOSTNAME="$1"

if [[ ! -e "$HOME/.local/bin/mise" ]]; then
	echo "==> Installing mise..."
	curl https://mise.run | sh
	export PATH="$HOME/.local/bin:$PATH"
	echo
fi

echo "==> Handing off to mise..."
mise run "nix:init" "$HOSTNAME"
