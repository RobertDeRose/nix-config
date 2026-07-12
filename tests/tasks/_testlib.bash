#!/usr/bin/env bash

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_eq() {
  local expected="$1" actual="$2" context="${3:-values differ}"
  [ "$actual" = "$expected" ] || fail "$context: expected '$expected', got '$actual'"
}

assert_contains() {
  local haystack="$1" needle="$2" context="${3:-missing text}"
  case "$haystack" in
    *"$needle"*) ;;
    *) fail "$context: expected to find '$needle'" ;;
  esac
}

assert_file_contains() {
  local file="$1" needle="$2"
  grep -Fq -- "$needle" "$file" || fail "$file does not contain: $needle"
}

assert_success() {
  "$@" || fail "command failed: $*"
}

assert_failure() {
  if "$@"; then
    fail "command unexpectedly succeeded: $*"
  fi
}

make_git_repo() {
  local path="$1"
  git -C "$path" init -q
  git -C "$path" config user.name 'Task Test'
  git -C "$path" config user.email 'task-test@example.invalid'
  git -C "$path" add -A
  git -C "$path" commit -qm baseline
}
