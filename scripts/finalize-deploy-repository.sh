#!/usr/bin/env sh
# Commit or roll back the repository transaction created by deploy-repository.sh.
set -eu

repo_path="${1:?usage: finalize-deploy-repository.sh <repo-path> <managed-user> <commit|rollback>}"
managed_user="${2:?usage: finalize-deploy-repository.sh <repo-path> <managed-user> <commit|rollback>}"
action="${3:?usage: finalize-deploy-repository.sh <repo-path> <managed-user> <commit|rollback>}"
managed_home="${MAISON_MANAGED_HOME:-/home/$managed_user}"
previous="${repo_path}.previous"
state="${repo_path}.deploy-state"

case "$managed_user" in '' | root | *[!a-z0-9_-]*) exit 2 ;; esac
case "$repo_path" in "$managed_home"/*) ;; *) exit 2 ;; esac
case "$repo_path" in
  *[!A-Za-z0-9_./-]* | *'//'* | */ | *'/./'* | *'/../'* | *'/.' | *'/..') exit 2 ;;
esac
case "$action" in commit | rollback) ;; *) exit 2 ;; esac

if [ "$(id -u)" -eq 0 ] || [ "$(id -un)" = "$managed_user" ]; then
  as_root() { "$@"; }
else
  command -v sudo >/dev/null 2>&1 || {
    printf 'error: sudo is required to manage the repository for %s\n' "$managed_user" >&2
    exit 1
  }
  as_root() { sudo "$@"; }
fi

as_root id "$managed_user" >/dev/null 2>&1 || {
  printf 'error: managed user does not exist: %s\n' "$managed_user" >&2
  exit 1
}
as_root test -d "$managed_home" || {
  printf 'error: managed home does not exist: %s\n' "$managed_home" >&2
  exit 1
}
home_real="$(as_root readlink -f -- "$managed_home")" || exit 1
parent_real="$(as_root readlink -f -- "$(dirname "$repo_path")")" || exit 1
case "$parent_real" in
  "$home_real" | "$home_real"/*) ;;
  *)
    printf 'error: repository parent now resolves outside %s: %s\n' "$managed_home" "$parent_real" >&2
    exit 1
    ;;
esac

if ! as_root test -f "$state" || as_root test -L "$state"; then
  printf 'error: deployment state is missing or unsafe: %s\n' "$state" >&2
  exit 1
fi
state_value="$(as_root cat "$state")"
case "$state_value" in previous | absent) ;; *) exit 1 ;; esac

if [ "$state_value" = previous ]; then
  if ! as_root test -d "$previous" || as_root test -L "$previous"; then
    printf 'error: previous repository is missing or unsafe: %s\n' "$previous" >&2
    exit 1
  fi
fi

if [ "$action" = commit ]; then
  as_root rm -rf -- "$previous"
  as_root rm -f -- "$state"
  printf 'Committed Maison repository transaction at %s\n' "$repo_path"
  exit 0
fi

as_root rm -rf -- "$repo_path"
if [ "$state_value" = previous ]; then
  as_root mv -T -- "$previous" "$repo_path"
else
  as_root rm -rf -- "$previous"
fi
as_root rm -f -- "$state"
printf 'Rolled back Maison repository transaction at %s\n' "$repo_path"
