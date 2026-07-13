#!/usr/bin/env bash

repo_root() {
  local start="${1:-${BASH_SOURCE[1]:-${BASH_SOURCE[0]}}}"
  git -C "$(dirname "$start")" rev-parse --show-toplevel 2> /dev/null
}

log_info() { printf '==> %s\n' "$*"; }
log_warn() { printf 'warning: %s\n' "$*" >&2; }
log_error() { printf 'error: %s\n' "$*" >&2; }

die() {
  log_error "$*"
  return 1
}

require_command() {
  command -v "$1" > /dev/null 2>&1 || die "required command not found: $1"
}

is_ci() {
  [ "${CI:-false}" = "true" ] || [ "${CI:-}" = "1" ]
}

confirm() {
  local prompt="${1:-Continue?}" reply
  if is_ci; then
    return 1
  fi
  printf '%s [y/N] ' "$prompt" >&2
  IFS= read -r reply
  case "$reply" in
    y | Y | yes | YES | Yes) return 0 ;;
    *) return 1 ;;
  esac
}

json_escape() {
  printf '%s' "$1" | awk 'BEGIN { ORS="" } { gsub(/\\/, "\\\\"); gsub(/\"/, "\\\""); gsub(/\t/, "\\t"); gsub(/\r/, "\\r"); if (NR > 1) printf "\\n"; printf "%s", $0 }'
}
