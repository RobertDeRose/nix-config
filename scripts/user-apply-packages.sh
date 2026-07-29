#!/usr/bin/env bash
# Apply mise bootstrap packages and repair a narrowly scoped Docker Desktop
# ownership handoff when an existing Homebrew completion symlink blocks the
# built-in brew-cask installer.
set -euo pipefail

removed_targets=()
removed_links=()
handoff_pending=false

run_packages() {
  local output_file="$1"
  shift
  set +e
  mise bootstrap packages apply --yes "$@" 2>&1 | tee "$output_file"
  local status="${PIPESTATUS[0]}"
  set -e
  return "$status"
}

canonical_path() {
  local path="$1" link directory base count=0

  # Resolve the final symlink ourselves because macOS does not provide
  # readlink -f. Physical directory traversal still resolves symlinked parent
  # components without requiring Python during first-run package bootstrap.
  while [ -L "$path" ]; do
    count=$((count + 1))
    [ "$count" -le 16 ] || return 1
    link="$(readlink "$path")" || return 1
    case "$link" in
      /*) path="$link" ;;
      *) path="$(dirname "$path")/$link" ;;
    esac
  done

  directory="$(dirname "$path")"
  base="$(basename "$path")"
  [ -d "$directory" ] || return 1
  directory="$(cd -P "$directory" && pwd -P)" || return 1
  printf '%s/%s\n' "$directory" "$base"
}

reconcile_docker_completion_links() {
  local prefix="${MAISON_HOMEBREW_PREFIX:-/opt/homebrew}"
  local docker_app="${MAISON_DOCKER_APP:-/Applications/Docker.app}"
  local removed=false target source expected expected_path mapping raw_link
  local -a mappings=(
    "etc/bash_completion.d/docker|Contents/Resources/etc/docker.bash-completion"
    "etc/bash_completion.d/docker-compose|Contents/Resources/etc/docker-compose.bash-completion"
    "share/fish/vendor_completions.d/docker.fish|Contents/Resources/etc/docker.fish-completion"
    "share/fish/vendor_completions.d/docker-compose.fish|Contents/Resources/etc/docker-compose.fish-completion"
    "share/zsh/site-functions/_docker|Contents/Resources/etc/docker.zsh-completion"
    "share/zsh/site-functions/_docker-compose|Contents/Resources/etc/docker-compose.zsh-completion"
  )

  for mapping in "${mappings[@]}"; do
    target="$prefix/${mapping%%|*}"
    expected_path="$docker_app/${mapping#*|}"
    [ -L "$target" ] || continue
    [ -f "$expected_path" ] || continue
    source="$(canonical_path "$target")" || continue
    expected="$(canonical_path "$expected_path")" || continue
    [ "$source" = "$expected" ] || continue
    raw_link="$(readlink "$target")" || continue
    printf 'maison: removing unmanaged Docker Desktop completion link %s before retry\n' "$target" >&2
    rm -f "$target"
    removed_targets+=("$target")
    removed_links+=("$raw_link")
    removed=true
  done

  [ "$removed" = true ]
}

restore_docker_completion_links() {
  local index target
  for ((index = 0; index < ${#removed_targets[@]}; index++)); do
    target="${removed_targets[$index]}"
    if [ ! -e "$target" ] && [ ! -L "$target" ]; then
      ln -s "${removed_links[$index]}" "$target" || true
    fi
  done
}

output_file="$(mktemp "${TMPDIR:-/tmp}/maison-packages.XXXXXX")"
cleanup() {
  local status=$?
  trap - EXIT HUP INT TERM
  if [ "$handoff_pending" = true ]; then
    restore_docker_completion_links
  fi
  rm -f "$output_file"
  exit "$status"
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

if run_packages "$output_file" "$@"; then
  exit 0
else
  status=$?
fi

if grep -Fq "not owned by cask 'docker-desktop'" "$output_file" &&
  grep -Fq "completion target '" "$output_file" &&
  reconcile_docker_completion_links; then
  handoff_pending=true
  : >"$output_file"
  printf 'maison: retrying package convergence after Docker Desktop completion handoff\n' >&2
  if run_packages "$output_file" "$@"; then
    handoff_pending=false
    exit 0
  else
    status=$?
    restore_docker_completion_links
    handoff_pending=false
    exit "$status"
  fi
fi

exit "$status"
