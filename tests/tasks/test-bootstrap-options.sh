#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
source "$ROOT/tests/tasks/_testlib.bash"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/work" "$tmp/home"
real_git="$(command -v git)"
cat > "$tmp/bin/git" << 'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$MOCK_LOG/git"
case "$1" in
  rev-parse) exit 1 ;;
  clone)
    destination="${@: -1}"
    mkdir -p "$destination/.git"
    printf '[tools]\n' > "$destination/mise.toml"
    printf '{}\n' > "$destination/flake.nix"
    mkdir -p "$destination/bin" "$destination/.mise/lib"
    printf '#!/usr/bin/env bash\n' > "$destination/bin/maison"
    chmod +x "$destination/bin/maison"
    printf 'log_info() { :; }\ndie() { printf "%%s\\n" "$*" >&2; exit 1; }\n' > "$destination/.mise/lib/common.sh"
    printf 'current_os() { printf "linux\\n"; }\ncurrent_arch() { printf "aarch64\\n"; }\n' > "$destination/.mise/lib/platform.sh"
    printf 'install_linuxbrew_if_missing() { :; }\ninstall_nix_or_lix_if_missing() { :; }\n' > "$destination/.mise/lib/bootstrap.sh"
    ;;
  *) exec "$REAL_GIT" "$@" ;;
esac
MOCK
cat > "$tmp/bin/mise" << 'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$MOCK_LOG/mise"
exit 0
MOCK
cat > "$tmp/bin/uname" << 'MOCK'
#!/usr/bin/env bash
[ "$1" = -s ] && printf 'Linux\n' || /usr/bin/uname "$@"
MOCK
chmod +x "$tmp/bin/"*
mkdir -p "$tmp/log"
(
  cd "$tmp/work"
  HOME="$tmp/home" PATH="$tmp/bin:$PATH" MOCK_LOG="$tmp/log" REAL_GIT="$real_git" \
    REPO=environment/repo REF=environment-ref \
    bash "$ROOT/bootstrap.sh" --host cli-host --repo cli/repo --ref cli-ref
)
assert_file_contains "$tmp/log/git" 'clone --branch cli-ref --single-branch https://github.com/cli/repo.git'
assert_file_contains "$tmp/log/mise" 'trust'
assert_file_contains "$tmp/log/mise" 'run --skip-tools bootstrap -- --host cli-host'
assert_file_contains "$ROOT/bootstrap.sh" 'bootstrap_die() {'
[ -L "$tmp/home/.local/bin/maison" ] || fail 'bootstrap did not install the Maison command'

# Intentional literal shell source patterns.
# shellcheck disable=SC2016
assert_file_contains "$ROOT/.mise/tasks/bootstrap" 'usage_bin="$(mise which usage)"'
# shellcheck disable=SC2016
assert_file_contains "$ROOT/.mise/tasks/bootstrap" 'ln -sfn "$usage_bin" "$HOME/.local/bin/usage"'

# Root bootstrap establishes platform prerequisites before delegating to Maison.
brew_line="$(grep -n 'install_linuxbrew_if_missing' "$ROOT/bootstrap.sh" | head -n1 | cut -d: -f1)"
mise_line="$(grep -n 'if ! command -v mise' "$ROOT/bootstrap.sh" | head -n1 | cut -d: -f1)"
nix_line="$(grep -n 'install_nix_or_lix_if_missing' "$ROOT/bootstrap.sh" | head -n1 | cut -d: -f1)"
[ "$brew_line" -lt "$mise_line" ] || fail 'bootstrap must install Homebrew before mise'
[ "$mise_line" -lt "$nix_line" ] || fail 'bootstrap must install mise before Nix/Lix'
