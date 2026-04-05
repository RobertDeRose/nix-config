#!/usr/bin/env bash
# bootstrap.sh — Bootstrap a new machine from scratch.
# Usage:
#   ./bootstrap.sh [hostname]
# or, for a one-liner from the web:
#   curl -sSfL https://raw.githubusercontent.com/RobertDeRose/nix-config/main/bootstrap.sh | bash -s -- [hostname]

set -euo pipefail

HOSTNAME="$1"
REPO="RobertDeRose/nix-config"
REPO_URL="https://github.com/${REPO}.git"
REPO_DIR="$(basename "$REPO")"

# ------------------------------------------------------------------ #
# macOS: install Xcode Command Line Tools if missing
# ------------------------------------------------------------------ #
if [[ "$(uname -s)" == "Darwin" ]] && ! xcode-select -p &>/dev/null; then
	echo "==> Installing Xcode Command Line Tools..."
	touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress

	PROD=$(softwareupdate -l 2>/dev/null | grep "\*.*Command Line" | tail -n 1 | sed 's/^[^C]* //')

	if [[ -n "$PROD" ]]; then
		softwareupdate -i "$PROD" --verbose
		rm -f /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
		echo "    Xcode Command Line Tools installed."
	else
		rm -f /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
		echo "ERROR: No Command Line Tools update found via softwareupdate."
		echo "       Install manually: xcode-select --install"
		exit 1
	fi
fi

# ------------------------------------------------------------------ #
# Linux: install git if missing
# ------------------------------------------------------------------ #
if [[ "$(uname -s)" == "Linux" ]] && ! command -v git &>/dev/null; then
	echo "==> Installing git..."
	sudo apt-get update -qq && sudo apt-get install -yqq git
fi

# ------------------------------------------------------------------ #
# Ensure we're inside the nix-config repo
# ------------------------------------------------------------------ #
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
	echo "==> Cloning nix-config into ./$REPO_DIR..."
	git clone "$REPO_URL"
	cd "$REPO_DIR"
fi

# ------------------------------------------------------------------ #
# Install mise if missing
# ------------------------------------------------------------------ #
if ! command -v mise &>/dev/null; then
	if [[ ! -e "$HOME/.local/bin/mise" ]]; then
		echo "==> Installing mise..."
		curl https://mise.run | sh
	fi
	export PATH="$HOME/.local/bin:$PATH"
	echo
fi

echo "==> Handing off to mise..."
mise run init "$HOSTNAME"
