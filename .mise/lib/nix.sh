#!/usr/bin/env bash

load_nix_environment() {
  if command -v nix >/dev/null 2>&1; then
    return 0
  fi
  if [ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
    set +u
    # shellcheck disable=SC1091
    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
    set -u
  fi
  command -v nix >/dev/null 2>&1 || die "Nix or Lix is not available"
}

configure_github_access_token() {
  local token=""
  [ -z "${GITHUB_TOKEN:-}" ] || return 0
  if command -v gh >/dev/null 2>&1; then
    token="$(gh auth token 2>/dev/null || true)"
  elif command -v mise >/dev/null 2>&1; then
    token="$(mise x gh -- gh auth token 2>/dev/null || true)"
  fi
  if [ -n "$token" ]; then
    export GITHUB_TOKEN="$token"
    export NIX_CONFIG="${NIX_CONFIG:-}${NIX_CONFIG:+
}access-tokens = github.com=$token"
  fi
}

nix_common_flags() {
  local debug="${1:-false}"
  printf '%s\n' --accept-flake-config --extra-experimental-features 'nix-command flakes'
  if [ "$debug" = true ]; then
    printf '%s\n' --show-trace --verbose
  fi
}

nix_command() {
  local debug="$1"
  shift
  local flags=() flag
  while IFS= read -r flag; do flags+=("$flag"); done < <(nix_common_flags "$debug")
  nix "${flags[@]}" "$@"
}

darwin_target_for_host() {
  printf '%s#darwinConfigurations.%s.system\n' "$1" "$2"
}

linux_system_target_for_host() {
  printf '%s#systemConfigs.%s\n' "$1" "$2"
}

linux_home_target_for_host() {
  printf '%s#homeConfigurations.%s.activationPackage\n' "$1" "$2"
}

resolved_target_for_host() {
  local root="$1" host="$2" system
  system="$(inventory_host_system "$root" "$host")"
  case "$system" in
    *-darwin) darwin_target_for_host "$root" "$host" ;;
    *-linux) linux_system_target_for_host "$root" "$host" ;;
    *) return 1 ;;
  esac
}

evaluate_host() {
  local root="$1" host="$2" debug="${3:-false}" system target
  system="$(inventory_host_system "$root" "$host")"
  case "$system" in
    *-darwin)
      target="$(darwin_target_for_host "$root" "$host")"
      test "$(nix_command "$debug" eval --raw "$target.type")" = derivation
      ;;
    *-linux)
      target="$(linux_system_target_for_host "$root" "$host")"
      test "$(nix_command "$debug" eval --raw "$target.type")" = derivation
      target="$(linux_home_target_for_host "$root" "$host")"
      test "$(nix_command "$debug" eval --raw "$target.type")" = derivation
      ;;
    *) die "unsupported host system: $system" ;;
  esac
}

build_host() {
  local root="$1" host="$2" debug="${3:-false}" system
  system="$(inventory_host_system "$root" "$host")"
  mkdir -p "$root/.build"
  case "$system" in
    *-darwin)
      nix_command "$debug" build --out-link "$root/.build/darwin-$host" "$(darwin_target_for_host "$root" "$host")"
      ;;
    *-linux)
      nix_command "$debug" build --out-link "$root/.build/system-$host" "$(linux_system_target_for_host "$root" "$host")"
      nix_command "$debug" build --out-link "$root/.build/home-$host" "$(linux_home_target_for_host "$root" "$host")"
      nix_command "$debug" build --out-link "$root/.build/system-manager" "$root#system-manager"
      ;;
    *) die "unsupported host system: $system" ;;
  esac
}

dry_run_host() {
  local root="$1" host="$2" debug="${3:-false}" system
  system="$(inventory_host_system "$root" "$host")"
  case "$system" in
    *-darwin)
      nix_command "$debug" build --dry-run -L "$(darwin_target_for_host "$root" "$host")"
      ;;
    *-linux)
      nix_command "$debug" build --dry-run -L "$(linux_system_target_for_host "$root" "$host")"
      nix_command "$debug" build --dry-run -L "$(linux_home_target_for_host "$root" "$host")"
      ;;
    *) die "unsupported host system: $system" ;;
  esac
}

prepare_darwin_activation() {
  if [ ! -f /etc/nix/nix.conf ] && [ -f /etc/nix/nix.conf.before-nix-darwin ]; then
    log_info "Restoring /etc/nix/nix.conf for the activation preflight"
    sudo cp /etc/nix/nix.conf.before-nix-darwin /etc/nix/nix.conf
    sudo launchctl kickstart -k system/org.nixos.nix-daemon
    sleep 2
  fi
  if [ -f /etc/nix/nix.conf ] && ! grep -qF nix-darwin /etc/nix/nix.conf 2>/dev/null; then
    log_info "Moving unmanaged /etc/nix/nix.conf aside for nix-darwin"
    sudo mv /etc/nix/nix.conf /etc/nix/nix.conf.before-nix-darwin
  fi
  if [ ! -e /run/current-system/darwin-version ] && [ -f /etc/nix/nix.custom.conf ]; then
    log_info "Moving unmanaged /etc/nix/nix.custom.conf aside for nix-darwin"
    sudo mv /etc/nix/nix.custom.conf /etc/nix/nix.custom.conf.before-nix-darwin
  fi
}

activate_darwin_host() {
  local root="$1" host="$2" debug="${3:-false}" flags=()
  [ "$debug" = true ] && flags+=(--show-trace --verbose)
  prepare_darwin_activation
  sudo "$root/.build/darwin-$host/sw/bin/darwin-rebuild" switch --flake "$root#$host" "${flags[@]}"
}

activate_linux_system() {
  local root="$1" host="$2"
  "$root/.build/system-manager/bin/system-manager" switch --flake "$root#$host" --sudo
}

activate_linux_home() {
  local root="$1" host="$2" username home group activation_path
  username="$(require_inventory_user_for_host "$root" "$host")"
  home="$(home_directory_for_user "$username")"
  group="$(id -gn "$username" 2>/dev/null || printf '%s' "$username")"
  activation_path="/nix/var/nix/profiles/default/bin:/run/current-system/sw/bin:${PATH:-/usr/bin:/bin}"
  sudo install -d -m755 -o "$username" -g "$group" "/nix/var/nix/profiles/per-user/$username"
  if [ "$(id -un)" = "$username" ]; then
    USER="$username" HOME="$home" PATH="$activation_path" HOME_MANAGER_BACKUP_EXT=hm_bak "$root/.build/home-$host/activate"
  else
    sudo -u "$username" env USER="$username" HOME="$home" PATH="$activation_path" HOME_MANAGER_BACKUP_EXT=hm_bak "$root/.build/home-$host/activate"
  fi
}

activate_host() {
  local root="$1" host="$2" debug="${3:-false}" system
  system="$(inventory_host_system "$root" "$host")"
  case "$system" in
    *-darwin) activate_darwin_host "$root" "$host" "$debug" ;;
    *-linux)
      activate_linux_system "$root" "$host"
      activate_linux_home "$root" "$host"
      ;;
    *) die "unsupported host system: $system" ;;
  esac
}
