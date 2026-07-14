#!/usr/bin/env bash

apple_container_state() {
  local name="$1"

  container inspect "$name" 2> /dev/null |
    jq -r '.[0].status.state // "unknown"'
}

apple_container_ipv4() {
  local name="$1"

  container inspect "$name" |
    jq -er '
      (
        .[0].status.networks[0].ipv4Address
        // .[0].networks[0].ipv4Address
        // empty
      )
      | split("/")[0]
      | select(length > 0)
    '
}

print_apple_container_diagnostics() {
  local name="$1"

  printf '\nContainer inspection:\n' >&2
  container inspect "$name" >&2 || true

  printf '\nContainer logs:\n' >&2
  container logs "$name" >&2 || true
}

wait_for_apple_container() {
  local name="$1"
  local attempts="${2:-60}"
  local delay="${3:-1}"
  local attempt state

  for ((attempt = 1; attempt <= attempts; attempt++)); do
    state="$(apple_container_state "$name")"

    case "$state" in
      running)
        if container exec "$name" true > /dev/null 2>&1; then
          return 0
        fi
        ;;
      stopped)
        printf "ERROR: Apple container '%s' stopped during startup.\n" "$name" >&2
        print_apple_container_diagnostics "$name"
        return 1
        ;;
    esac

    sleep "$delay"
  done

  printf "ERROR: Apple container '%s' did not become ready after %s attempt(s).\n" \
    "$name" "$attempts" >&2
  print_apple_container_diagnostics "$name"
  return 1
}
