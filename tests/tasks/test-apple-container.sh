#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
source "$ROOT/tests/tasks/_testlib.bash"
source "$ROOT/.mise/lib/apple-container.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/log"

cat > "$tmp/bin/container" << 'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$MOCK_LOG/calls"

case "$1" in
  inspect)
    case "${MOCK_STATE:-running}" in
      running)
        printf '%s\n' '[{"status":{"state":"running","networks":[{"ipv4Address":"192.168.64.9/24"}]}}]'
        ;;
      stopped)
        printf '%s\n' '[{"status":{"state":"stopped","networks":[]}}]'
        ;;
      *)
        printf '%s\n' '[{"status":{"state":"starting","networks":[]}}]'
        ;;
    esac
    ;;
  exec)
    [ "${MOCK_EXEC_FAIL:-false}" != true ]
    ;;
  logs)
    printf '%s\n' 'mock container logs'
    ;;
  *)
    exit 2
    ;;
esac
MOCK
chmod +x "$tmp/bin/container"

PATH="$tmp/bin:$PATH" MOCK_LOG="$tmp/log" wait_for_apple_container test 1 0
assert_eq 192.168.64.9 "$(PATH="$tmp/bin:$PATH" MOCK_LOG="$tmp/log" apple_container_ipv4 test)" 'Apple container IPv4 parsing'

if PATH="$tmp/bin:$PATH" MOCK_LOG="$tmp/log" MOCK_STATE=stopped \
  wait_for_apple_container test 1 0 > /dev/null 2>&1; then
  fail 'stopped Apple container unexpectedly became ready'
fi
assert_file_contains "$tmp/log/calls" 'logs test'

if PATH="$tmp/bin:$PATH" MOCK_LOG="$tmp/log" MOCK_STATE=running MOCK_EXEC_FAIL=true \
  wait_for_apple_container test 1 0 > /dev/null 2>&1; then
  fail 'unresponsive running Apple container unexpectedly became ready'
fi

for task in "$ROOT/.mise/tasks/test/bootstrap" "$ROOT/.mise/tasks/test/deploy"; do
  assert_file_contains "$task" '--cap-add ALL'
  assert_file_contains "$task" '--tmpfs /run'
  assert_file_contains "$task" '--tmpfs /tmp'
  assert_file_contains "$task" '/lib/systemd/systemd --system'
done

assert_file_contains "$ROOT/.mise/tasks/test/bootstrap" '--host %q --repo %q --ref %q --profiles %q'
assert_file_contains "$ROOT/.mise/tasks/test/bootstrap" 'sudo -iu tester'
assert_file_contains "$ROOT/.mise/tasks/test/bootstrap" 'gh auth token'
assert_file_contains "$ROOT/.mise/tasks/test/bootstrap" 'requires GitHub authentication'
assert_file_contains "$ROOT/.mise/tasks/test/bootstrap" 'mise run test:image'
assert_file_contains "$ROOT/.mise/tasks/test/bootstrap" 'GITHUB_TOKEN='
assert_file_contains "$ROOT/.mise/tasks/test/bootstrap" '#USAGE flag "--dev"'
assert_file_contains "$ROOT/.mise/tasks/test/bootstrap" 'PROFILES="base,linux"'
assert_file_contains "$ROOT/.mise/tasks/test/bootstrap" 'PROFILES="base,dev,linux"'
# Intentional literal shell source pattern.
# shellcheck disable=SC2016
assert_file_contains "$ROOT/.mise/tasks/test/bootstrap" 'bash -lc "$bootstrap_command"'
# Intentional literal shell source pattern.
# shellcheck disable=SC2016
if grep -Fq 'bash -s -- "$HOSTNAME"' "$ROOT/.mise/tasks/test/bootstrap"; then
  fail 'bootstrap integration task still uses the legacy positional hostname invocation'
fi

assert_file_contains "$ROOT/test/Containerfile" 'CMD ["/bin/bash"]'
assert_file_contains "$ROOT/.mise/tasks/deploy" 'Installing Maison repository and command'
assert_file_contains "$ROOT/.mise/tasks/deploy" 'ln -sfn "$managed_home/.maison/bin/maison"'
assert_file_contains "$ROOT/.mise/tasks/test/deploy" 'test -x "$HOME/.local/bin/maison"'

assert_file_contains "$ROOT/bin/maison" 'run --skip-tools "$task"'
assert_file_contains "$ROOT/bootstrap.sh" 'mise run --skip-tools bootstrap'
assert_file_contains "$ROOT/.mise/lib/bootstrap.sh" 'mise run --skip-tools github:auth'
assert_file_contains "$ROOT/.mise/tasks/bootstrap" 'Installing Maison project tools'
assert_file_contains "$ROOT/.mise/tasks/deploy" 'MISE_GITHUB_TOKEN="$github_token"'
assert_file_contains "$ROOT/.mise/tasks/deploy" 'trust "$managed_home/.maison/mise.toml"'
assert_file_contains "$ROOT/.mise/tasks/deploy" '"$mise_bin" -C "$managed_home/.maison" install'
