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

assert_file_contains "$ROOT/.mise/tasks/test/deploy" 'curl -sSfL https://mise.run | sh'
assert_file_contains "$ROOT/.mise/tasks/test/deploy" 'exec -- wt --version'
assert_file_contains "$ROOT/.mise/tasks/test/deploy" 'gh auth token'
assert_file_contains "$ROOT/.mise/tasks/test/deploy" 'requires GitHub authentication'
assert_file_contains "$ROOT/.mise/tasks/test/deploy" 'export GITHUB_TOKEN='
assert_file_contains "$ROOT/.mise/tasks/deploy" '--nix-option accept-flake-config true'
assert_file_contains "$ROOT/.mise/tasks/deploy" 'manager_args+=(--sudo)'
assert_file_contains "$ROOT/.mise/tasks/deploy" 'GitHub authentication is required for remote mise installation'
assert_file_contains "$ROOT/.mise/tasks/deploy" 'mktemp /tmp/maison-github-token.XXXXXX'
# Intentional literal shell source pattern.
# shellcheck disable=SC2016
assert_file_contains "$ROOT/.mise/tasks/deploy" 'GITHUB_TOKEN="$github_token"'
if grep -Fq -- '--ask-sudo-password' "$ROOT/.mise/tasks/deploy"; then
  fail 'deploy task still requests an interactive sudo password'
fi
assert_file_contains "$ROOT/.mise/tasks/deploy" 'run bootstrap first'
# Intentional literal shell source pattern.
# shellcheck disable=SC2016
assert_file_contains "$ROOT/.mise/tasks/deploy" 'MISE_CONFIG_FILE="$mise_config" GITHUB_TOKEN="$github_token" "$mise_bin" install'

for task in "$ROOT/.mise/tasks/test/bootstrap" "$ROOT/.mise/tasks/test/deploy"; do
  # Intentional literal shell source pattern.
  # shellcheck disable=SC2016
  assert_file_contains "$task" 'install_apple_container_test_signal_handlers "$NAME"'
  assert_file_contains "$task" 'run_apple_container_test_command'
done

assert_file_contains "$ROOT/.mise/lib/apple-container.sh" "trap 'interrupt_apple_container_test INT' INT"
assert_file_contains "$ROOT/.mise/lib/apple-container.sh" "trap 'interrupt_apple_container_test TERM' TERM"
# Intentional literal shell source pattern.
# shellcheck disable=SC2016
assert_file_contains "$ROOT/.mise/lib/apple-container.sh" 'container stop "$name"'
# Intentional literal shell source pattern.
# shellcheck disable=SC2016
assert_file_contains "$ROOT/.mise/lib/apple-container.sh" 'container delete --force "$name"'
assert_file_contains "$ROOT/.mise/lib/apple-container.sh" "129) interrupt_apple_container_test HUP"
assert_file_contains "$ROOT/.mise/lib/apple-container.sh" "130) interrupt_apple_container_test INT"
assert_file_contains "$ROOT/.mise/lib/apple-container.sh" "141) interrupt_apple_container_test PIPE"
assert_file_contains "$ROOT/.mise/lib/apple-container.sh" "143) interrupt_apple_container_test TERM"

assert_file_contains "$ROOT/test/Containerfile" 'CMD ["/bin/bash"]'
assert_file_contains "$ROOT/.mise/tasks/deploy" 'Installing Maison repository and command'
# Intentional literal shell source pattern.
# shellcheck disable=SC2016
assert_file_contains "$ROOT/.mise/tasks/deploy" 'ln -sfn "$managed_home/.maison/bin/maison"'
# Intentional literal shell source pattern.
# shellcheck disable=SC2016
assert_file_contains "$ROOT/.mise/tasks/test/deploy" 'test -x "$HOME/.local/bin/maison"'

# Intentional literal shell source pattern.
# shellcheck disable=SC2016
assert_file_contains "$ROOT/bin/maison" 'run --skip-tools "$task"'
assert_file_contains "$ROOT/bootstrap.sh" 'mise run --skip-tools bootstrap'
assert_file_contains "$ROOT/.mise/lib/bootstrap.sh" 'mise run --skip-tools github:auth'
assert_file_contains "$ROOT/.mise/tasks/bootstrap" 'Installing Maison project tools'
# Intentional literal shell source pattern.
# shellcheck disable=SC2016
assert_file_contains "$ROOT/.mise/tasks/deploy" 'MISE_GITHUB_TOKEN="$github_token"'
# Intentional literal shell source pattern.
# shellcheck disable=SC2016
assert_file_contains "$ROOT/.mise/tasks/deploy" 'trust "$managed_home/.maison/mise.toml"'
# Intentional literal shell source pattern.
# shellcheck disable=SC2016
assert_file_contains "$ROOT/.mise/tasks/deploy" '"$managed_home/.local/bin/mise" -C "$managed_home/.maison" install'
assert_file_contains "$ROOT/.mise/tasks/deploy" 'Global mise tool installation failed; retrying'
assert_file_contains "$ROOT/.mise/tasks/deploy" 'Maison project tool installation failed; retrying'
assert_file_contains "$ROOT/.mise/tasks/deploy" 'ssh_tty=(-T)'
assert_file_contains "$ROOT/.mise/tasks/deploy" 'ssh -T -o BatchMode=yes'
assert_file_contains "$ROOT/.mise/tasks/deploy" 'Homebrew for Linux is unavailable; run bootstrap first'
assert_file_contains "$ROOT/bootstrap.sh" 'install_linuxbrew_if_missing'
assert_file_contains "$ROOT/bootstrap.sh" 'install_nix_or_lix_if_missing'
assert_file_contains "$ROOT/.mise/tasks/test/deploy" 'Bootstrap order is part of the deployment contract: Homebrew, mise, Nix/Lix.'
# Intentional literal shell source pattern.
# shellcheck disable=SC2016
assert_file_contains "$ROOT/.mise/tasks/test/deploy" '/bin/bash -s -- "$remote_bootstrap_token_file"'
assert_file_contains "$ROOT/.mise/tasks/test/deploy" '-o LogLevel=ERROR'
assert_file_contains "$ROOT/.mise/tasks/test/deploy" 'test -x /home/linuxbrew/.linuxbrew/bin/brew'
# Intentional literal shell source pattern.
# shellcheck disable=SC2016
assert_file_contains "$ROOT/.mise/tasks/deploy" 'ln -sfn "$usage_bin" "$managed_home/.local/bin/usage"'

assert_file_contains "$ROOT/bootstrap.sh" 'export LANG=C.UTF-8'
assert_file_contains "$ROOT/bootstrap.sh" 'export LC_CTYPE=C.UTF-8'
# Intentional literal shell source pattern.
# shellcheck disable=SC2016
assert_file_contains "$ROOT/.mise/tasks/test/deploy" 'test "$(locale charmap)" = "UTF-8"'
assert_file_contains "$ROOT/.mise/tasks/test/deploy" '[[ -o multibyte ]]'
assert_file_contains "$ROOT/.mise/tasks/test/bootstrap" '[[ -o multibyte ]]'
