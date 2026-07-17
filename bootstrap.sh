#!/usr/bin/env bash
# Install Maison and hand machine setup to its mise-backed bootstrap task.
#
# Usage:
#   ./bootstrap.sh [--host HOST] [--repo OWNER/REPO|URL] [--ref REF] [--profiles LIST]
#   curl -fsSL https://raw.githubusercontent.com/RobertDeRose/maison/main/bootstrap.sh \
#     | bash -s -- --host HOST --repo RobertDeRose/maison --ref main

set -euo pipefail

log() { printf '==> %s\n' "$*"; }
die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

host="$(hostname -s)"
repo="${REPO:-RobertDeRose/maison}"
ref="${REF:-${BRANCH:-main}}"
profiles="${PROFILES:-}"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --host)
      [ "$#" -ge 2 ] || die "--host requires a value"
      host="$2"
      shift 2
      ;;
    --repo)
      [ "$#" -ge 2 ] || die "--repo requires a value"
      repo="$2"
      shift 2
      ;;
    --ref)
      [ "$#" -ge 2 ] || die "--ref requires a value"
      ref="$2"
      shift 2
      ;;
    --profiles)
      [ "$#" -ge 2 ] || die "--profiles requires a value"
      profiles="$2"
      shift 2
      ;;
    -h | --help)
      sed -n '2,8p' "${BASH_SOURCE[0]:-/dev/stdin}" 2> /dev/null || true
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -*) die "unknown option: $1" ;;
    *)
      # Preserve the original positional hostname interface.
      host="$1"
      shift
      ;;
  esac
done
[ "$#" -eq 0 ] || die "unexpected argument: $1"

run_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  else
    command -v sudo > /dev/null 2>&1 || die "sudo is required to install platform prerequisites"
    sudo "$@"
  fi
}

install_linux_prerequisites() {
  command -v git > /dev/null 2>&1 && command -v curl > /dev/null 2>&1 && return 0
  log "Installing git and curl"
  if command -v apt-get > /dev/null 2>&1; then
    run_root apt-get update -qq
    run_root apt-get install -y -qq git curl ca-certificates
  elif command -v dnf > /dev/null 2>&1; then
    run_root dnf install -y git curl ca-certificates
  elif command -v yum > /dev/null 2>&1; then
    run_root yum install -y git curl ca-certificates
  elif command -v pacman > /dev/null 2>&1; then
    run_root pacman -Sy --needed --noconfirm git curl ca-certificates
  elif command -v zypper > /dev/null 2>&1; then
    run_root zypper --non-interactive install git curl ca-certificates
  else
    die "install git and curl, then rerun bootstrap.sh"
  fi
}

install_macos_prerequisites() {
  command -v xcode-select > /dev/null 2>&1 || die "xcode-select is unavailable"
  if xcode-select -p > /dev/null 2>&1; then
    return 0
  fi
  log "Installing Xcode Command Line Tools"
  marker=/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
  touch "$marker"
  product="$(softwareupdate -l 2> /dev/null | awk '/\*.*Command Line/ { sub(/^[^C]*/, ""); value=$0 } END { print value }')"
  rm -f "$marker"
  [ -n "$product" ] || die "no Command Line Tools update was found; run 'xcode-select --install'"
  run_root softwareupdate -i "$product" --verbose
}

case "$(uname -s)" in
  Darwin) install_macos_prerequisites ;;
  Linux) install_linux_prerequisites ;;
  *) die "unsupported operating system: $(uname -s)" ;;
esac
command -v git > /dev/null 2>&1 || die "git is unavailable"
command -v curl > /dev/null 2>&1 || die "curl is unavailable"

case "$repo" in
  http://* | https://* | ssh://* | git@*) repo_url="$repo" ;;
  *) repo_url="https://github.com/${repo%.git}.git" ;;
esac
repo_root=""
if git_root="$(git rev-parse --show-toplevel 2> /dev/null)" &&
  [ -f "$git_root/mise.toml" ] &&
  [ -f "$git_root/flake.nix" ]; then
  repo_root="$git_root"
elif [ -n "${MAISON_HOME:-}" ]; then
  repo_root="$MAISON_HOME"
elif [ -n "${NIX_CONFIG_DIR:-}" ]; then
  # Compatibility with installations created before the Maison rename.
  repo_root="$NIX_CONFIG_DIR"
else
  repo_root="$HOME/.maison"
fi

if [ ! -d "$repo_root/.git" ]; then
  [ ! -e "$repo_root" ] || die "$repo_root exists but is not a Git repository"
  log "Cloning $repo_url at $ref into $repo_root"
  git clone --branch "$ref" --single-branch "$repo_url" "$repo_root"
elif [ ! -f "$repo_root/mise.toml" ] || [ ! -f "$repo_root/flake.nix" ]; then
  die "$repo_root does not look like Maison"
else
  log "Using repository at $repo_root"
fi

cd "$repo_root"
export MISE_TRUSTED_CONFIG_PATHS="$repo_root${MISE_TRUSTED_CONFIG_PATHS:+:$MISE_TRUSTED_CONFIG_PATHS}"

# Bootstrap platform prerequisites before Maison or Home Manager can install
# managed Git configuration. The order is intentional: Homebrew, mise, Nix/Lix.
# shellcheck source=.mise/lib/common.sh
source "$repo_root/.mise/lib/common.sh"
# shellcheck source=.mise/lib/platform.sh
source "$repo_root/.mise/lib/platform.sh"
# shellcheck source=.mise/lib/bootstrap.sh
source "$repo_root/.mise/lib/bootstrap.sh"
install_linuxbrew_if_missing

if ! command -v mise > /dev/null 2>&1; then
  if [ ! -x "$HOME/.local/bin/mise" ]; then
    log "Installing mise"
    curl -fsSL https://mise.run | sh
  fi
  export PATH="$HOME/.local/bin:$PATH"
fi
command -v mise > /dev/null 2>&1 || die "mise installation did not place the executable on PATH"

install_nix_or_lix_if_missing

log "Installing Maison command"
mkdir -p "$HOME/.local/bin"
ln -sfn "$repo_root/bin/maison" "$HOME/.local/bin/maison"

log "Trusting repository configuration"
mise trust "$repo_root/mise.toml" > /dev/null

log "Handing off to Maison for host $host"
bootstrap_args=(--host "$host")
[ -z "$profiles" ] || bootstrap_args+=(--profiles "$profiles")
exec mise run --skip-tools bootstrap -- "${bootstrap_args[@]}"
