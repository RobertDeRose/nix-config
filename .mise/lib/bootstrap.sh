#!/usr/bin/env bash

wait_for_nix_daemon() {
  for _i in $(seq 1 30); do
    [ -S /nix/var/nix/daemon-socket/socket ] && return 0
    sleep 1
  done
  return 1
}

verify_nix() {
  if ! command -v nix > /dev/null 2>&1 && [ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
    set +u
    # shellcheck disable=SC1091
    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
    set -u
  fi
  command -v nix > /dev/null 2>&1 && nix --version > /dev/null
}

install_nix_or_lix_if_missing() {
  local os arch installer_rc=0 extra_conf
  if verify_nix; then
    log_info "Nix is already installed"
    return 0
  fi

  os="$(current_os)"
  arch="$(current_arch)"
  export NIX_INSTALLER_NO_CONFIRM=true
  export NIX_INSTALLER_ENABLE_FLAKES=true
  extra_conf="trusted-users = root $(id -un)
fallback = true
extra-substituters = https://cache.nixos.org https://nix-community.cachix.org https://cache.numtide.com
extra-trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs= niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
  if [ -n "${NIX_CONFIG_EXTRA_SUBSTITUTERS:-}" ]; then
    extra_conf="$extra_conf
extra-substituters = ${NIX_CONFIG_EXTRA_SUBSTITUTERS}"
  fi
  if [ "${NIX_INSTALLER_NO_SANDBOX:-false}" = true ]; then
    extra_conf="$extra_conf
sandbox = false"
  fi
  export NIX_INSTALLER_EXTRA_CONF="$extra_conf"

  if [ "$os" = darwin ]; then
    export NIX_INSTALLER_SSL_CERT_FILE=/etc/ssl/cert.pem
  fi

  if [ "$os" = darwin ] && [ "$arch" = x86_64 ]; then
    log_info "Installing Nix for Intel macOS"
    curl -sSfL https://artifacts.nixos.org/nix-installer | bash -s -- install
  else
    log_info "Installing Lix"
    curl -sSfL https://install.lix.systems/lix | bash -s -- install || installer_rc=$?
    if [ "$installer_rc" -ne 0 ]; then
      log_warn "Lix installer exited with status $installer_rc; verifying daemon readiness"
    fi
  fi

  wait_for_nix_daemon || log_warn "Nix daemon socket did not appear within the initial wait window"
  verify_nix || die "Nix/Lix installation completed but the nix command is not functional"
}

install_linuxbrew_if_missing() {
  [ "$(current_os)" = linux ] || return 0
  if command -v brew > /dev/null 2>&1 || [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv 2> /dev/null || true)"
    return 0
  fi
  log_info "Installing Homebrew for Linux"
  if command -v apt-get > /dev/null 2>&1; then
    sudo apt-get update
    sudo apt-get install -y build-essential procps curl file git
  elif command -v dnf > /dev/null 2>&1; then
    sudo dnf group install -y development-tools
    sudo dnf install -y procps-ng curl file git
  elif command -v pacman > /dev/null 2>&1; then
    sudo pacman -Sy --needed --noconfirm base-devel procps-ng curl file git
  elif command -v zypper > /dev/null 2>&1; then
    sudo zypper --non-interactive install -t pattern devel_basis
    sudo zypper --non-interactive install procps curl file git
  else
    die "unsupported Linux package manager; install Homebrew prerequisites manually"
  fi
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  [ -x /home/linuxbrew/.linuxbrew/bin/brew ] || die "Homebrew installation did not create /home/linuxbrew/.linuxbrew/bin/brew"
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
}

ensure_github_auth() {
  local token=""
  token="$(mise token github --raw 2> /dev/null || true)"
  if [ -z "$token" ] && command -v gh > /dev/null 2>&1; then
    token="$(gh auth token 2> /dev/null || true)"
  fi
  if is_ci; then
    die "GitHub CLI is not authenticated and interactive login is disabled in CI"
  fi
  log_info "Starting GitHub CLI authentication"
  mise x gh -- gh auth login
}
