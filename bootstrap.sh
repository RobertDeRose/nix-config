#!/usr/bin/env bash
# bootstrap.sh — Bootstrap a new machine from scratch.
# Can be run locally (./bootstrap.sh <hostname>) or piped via curl:
#   curl -sSfL https://raw.githubusercontent.com/RobertDeRose/nix-config/main/bootstrap.sh | bash -s -- <hostname>
set -euo pipefail

REPO_URL="https://github.com/RobertDeRose/nix-config.git"
REPO_DIR="nix-config"

if [[ -z "${1:-}" ]]; then
	echo "Usage: $0 <hostname>"
	echo "Example: $0 rderose-mbp"
	exit 1
fi

HOSTNAME="$1"

# ------------------------------------------------------------------ #
# macOS: install Xcode Command Line Tools if missing
# ------------------------------------------------------------------ #
if [[ "$(uname -s)" == "Darwin" ]]; then
	if xcode-select -p &>/dev/null; then
		echo "==> Xcode Command Line Tools already installed."
	else
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
fi

# ------------------------------------------------------------------ #
# Linux: install git if missing
# ------------------------------------------------------------------ #
if [[ "$(uname -s)" == "Linux" ]] && ! command -v git &>/dev/null; then
	echo "==> Installing git..."
	if command -v apt-get &>/dev/null; then
		sudo apt-get update -qq && sudo apt-get install -yqq git
	elif command -v dnf &>/dev/null; then
		sudo dnf install -y git
	elif command -v pacman &>/dev/null; then
		sudo pacman -Sy --noconfirm git
	elif command -v zypper &>/dev/null; then
		sudo zypper install -y git
	else
		echo "ERROR: Could not detect package manager to install git."
		echo "       Install git manually, then re-run this script."
		exit 1
	fi
fi

# ------------------------------------------------------------------ #
# Ensure we're inside the nix-config repo
# ------------------------------------------------------------------ #
if git rev-parse --is-inside-work-tree &>/dev/null && [[ -f mise.toml ]]; then
	echo "==> Already inside nix-config repo."
else
	echo "==> Cloning nix-config into ./$REPO_DIR..."
	git clone "$REPO_URL" "$REPO_DIR"
	cd "$REPO_DIR"
fi

# ------------------------------------------------------------------ #
# Install mise if missing
# ------------------------------------------------------------------ #
if [[ ! -e "$HOME/.local/bin/mise" ]]; then
	echo "==> Installing mise..."
	curl https://mise.run | sh
	export PATH="$HOME/.local/bin:$PATH"
	echo
fi

echo "==> Handing off to mise..."
mise run init "$HOSTNAME"
