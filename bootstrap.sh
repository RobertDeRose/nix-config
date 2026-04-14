#!/usr/bin/env bash
# bootstrap.sh — Bootstrap a new machine from scratch.
# Usage:
#   ./bootstrap.sh [hostname]
# or, for a one-liner from the web:
#   sh -c 'curl -sSfL https://raw.githubusercontent.com/RobertDeRose/nix-config/main/bootstrap.sh | bash -s -- [hostname]'
# To test a branch or fork before merging:
#   sh -c 'curl -sSfL https://raw.githubusercontent.com/RobertDeRose/nix-config/fix/fresh-bootstrap/bootstrap.sh | bash -s -- [hostname]'
#   sh -c 'curl -sSfL https://raw.githubusercontent.com/SomeoneElse/nix-config/main/bootstrap.sh | bash -s -- [hostname]'
# The repo and branch are auto-detected from the curl URL visible in ps;
# BRANCH and REPO env vars are still supported as overrides.

set -euo pipefail

# ------------------------------------------------------------------ #
# Auto-detect repo and branch from the parent sh -c + curl process
# ------------------------------------------------------------------ #
_detect_from_curl() {
  # When invoked via sh -c 'curl URL | bash', the sh process stays alive
  # and ps -ef shows the full command line including the URL.
  local url
  # shellcheck disable=SC2009 # we need the full command args, not just PIDs
  url=$(ps -ef 2> /dev/null |
    grep -F 'raw.githubusercontent.com' |
    grep -F 'bootstrap.sh' |
    grep -v grep |
    head -n1 |
    grep -oE 'https://raw\.githubusercontent\.com/[^ ]+' |
    head -n1) || true

  if [[ -n ${url:-} ]]; then
    # URL: https://raw.githubusercontent.com/<owner>/<repo>/<branch>/bootstrap.sh
    local path="${url#https://raw.githubusercontent.com/}"
    local owner="${path%%/*}"
    path="${path#*/}"
    local repo="${path%%/*}"
    path="${path#*/}"
    local branch="${path%/bootstrap.sh}"

    if [[ -n $owner && -n $repo && -n $branch ]]; then
      echo "${owner}/${repo}" "$branch"
    fi
  fi
}

HOSTNAME="${1:-$(hostname -s)}"

# Auto-detect repo/branch from curl URL, with env var overrides
if [[ -z ${REPO:-} || -z ${BRANCH:-} ]]; then
  IFS=' ' read -r -a _detected <<< "$(_detect_from_curl)" || true
  REPO="${REPO:-${_detected[0]:-RobertDeRose/nix-config}}"
  BRANCH="${BRANCH:-${_detected[1]:-main}}"
  unset _detected
else
  REPO="${REPO:-RobertDeRose/nix-config}"
  BRANCH="${BRANCH:-main}"
fi

if [[ $REPO != "RobertDeRose/nix-config" || $BRANCH != "main" ]]; then
  echo "==> Using repo=$REPO branch=$BRANCH"
fi
REPO_URL="https://github.com/${REPO}.git"
REPO_DIR="$(basename "$REPO")"
MISE_CEILING_PATHS="$(realpath "$(pwd)/..")"

# ------------------------------------------------------------------ #
# macOS: install Xcode Command Line Tools if missing
# ------------------------------------------------------------------ #
if [[ "$(uname -s)" == "Darwin" ]] && ! xcode-select -p &> /dev/null; then
  echo "==> Installing Xcode Command Line Tools..."
  touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress

  PROD=$(softwareupdate -l 2> /dev/null | grep "\*.*Command Line" | tail -n 1 | sed 's/^[^C]* //')

  if [[ -n $PROD ]]; then
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
if [[ "$(uname -s)" == "Linux" ]] && ! command -v git &> /dev/null; then
  echo "==> Installing git..."
  command=("apt-get")
  [[ $(id -u) -ne 0 ]] && command=("sudo" "${command[@]}")
  "${command[@]}" update -qq && "${command[@]}" install -yqq git
fi

# ------------------------------------------------------------------ #
# Ensure we're inside the nix-config repo
# ------------------------------------------------------------------ #
if ! git rev-parse --is-inside-work-tree &> /dev/null; then
  echo "==> Cloning nix-config into ./$REPO_DIR (branch: $BRANCH)..."
  git clone -b "$BRANCH" "$REPO_URL"
  cd "$REPO_DIR"
fi

# ------------------------------------------------------------------ #
# Install mise if missing
# ------------------------------------------------------------------ #
if ! command -v mise &> /dev/null; then
  if [[ ! -e "$HOME/.local/bin/mise" ]]; then
    echo "==> Installing mise..."
    curl https://mise.run | sh
  fi
  export PATH="$HOME/.local/bin:$PATH"
  echo
fi

echo "==> Handing off to mise..."
export MISE_CEILING_PATHS
export MISE_AUTO_INSTALL=false
export MISE_TRUSTED_CONFIG_PATHS="${PWD}"
mise run nix:init "$HOSTNAME"
