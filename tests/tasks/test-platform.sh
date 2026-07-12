#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
source "$ROOT/tests/tasks/_testlib.bash"
source "$ROOT/.mise/lib/platform.sh"

mock_os=Darwin
mock_arch=arm64
uname() {
  case "$1" in
    -s) printf '%s\n' "$mock_os" ;;
    -m) printf '%s\n' "$mock_arch" ;;
    *) return 1 ;;
  esac
}

assert_eq darwin "$(current_os)" 'Darwin normalization'
assert_eq aarch64 "$(current_arch)" 'arm64 normalization'
assert_eq aarch64-darwin "$(current_system)" 'Apple Silicon system'

mock_os=Linux
mock_arch=x86_64
assert_eq linux "$(current_os)" 'Linux normalization'
assert_eq x86_64 "$(current_arch)" 'x86_64 normalization'
assert_eq x86_64-linux "$(current_system)" 'x86_64 Linux system'

mock_arch=aarch64
assert_eq aarch64-linux "$(current_system)" 'ARM64 Linux system'
mock_arch=mips
assert_failure current_arch
assert_success is_supported_system x86_64-darwin
assert_failure is_supported_system riscv64-linux
