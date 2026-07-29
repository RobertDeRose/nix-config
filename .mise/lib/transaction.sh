#!/usr/bin/env bash

transaction_directory() {
  mktemp -d "${TMPDIR:-/tmp}/maison-transaction.XXXXXX"
}

transaction_candidate() {
  local source="$1" directory="$2" candidate
  candidate="$directory/$(basename "$source")"
  cp -p "$source" "$candidate"
  printf '%s\n' "$candidate"
}

atomic_replace() {
  local candidate="$1" destination="$2" temporary
  temporary="$(dirname "$destination")/.maison.$(basename "$destination").$$.tmp"
  rm -f "$temporary"
  cp -p "$candidate" "$temporary"
  if ! mv -f "$temporary" "$destination"; then
    rm -f "$temporary"
    return 1
  fi
}

transaction_set_signal_traps() {
  trap 'exit 129' HUP
  trap 'exit 130' INT
  trap 'exit 143' TERM
}
