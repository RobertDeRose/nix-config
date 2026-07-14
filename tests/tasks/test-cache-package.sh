#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
source "$ROOT/tests/tasks/_testlib.bash"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin"

cat > "$tmp/bin/nix" << 'MOCK'
#!/usr/bin/env bash
set -euo pipefail

while (( $# > 0 )); do
  case "$1" in
    --accept-flake-config | --no-warn-dirty | --show-trace | --verbose)
      shift
      ;;
    --extra-experimental-features)
      shift 2
      ;;
    --option)
      shift 3
      ;;
    *)
      break
      ;;
  esac
done

case "$1" in
  eval)
    shift
    if [ "$1" = --impure ]; then
      printf 'aarch64-darwin'
      exit 0
    fi

    [ "$1" = --raw ] || exit 2
    shift
    [ "$1" = --apply ] || exit 2
    apply="$2"
    ref="$3"
    case "$ref:$apply" in
      *'#pi:package: package.outPath' | \
        github:numtide/llm-agents.nix*'#pi:package: package.outPath')
        printf '/nix/store/pi-out'
        ;;
      *'#pi:package: package.drvPath' | \
        github:numtide/llm-agents.nix*'#pi:package: package.drvPath')
        printf '/nix/store/pi.drv'
        ;;
      github:nixos/nixpkgs/*'#legacyPackages."aarch64-darwin"."bash":package: package.outPath')
        printf '/nix/store/bash-out'
        ;;
      github:nixos/nixpkgs/*'#legacyPackages."aarch64-darwin"."bash":package: package.drvPath')
        printf '/nix/store/bash.drv'
        ;;
      github:nixos/nixpkgs/*'#legacyPackages."aarch64-darwin"."python3.14":package: package.outPath')
        printf '/nix/store/python314-out'
        ;;
      github:nixos/nixpkgs/*'#legacyPackages."aarch64-darwin"."python3.14":package: package.drvPath')
        printf '/nix/store/python314.drv'
        ;;
      github:nixos/nixpkgs/*'#legacyPackages."aarch64-darwin"."python313Packages"."uvicorn":package: package.outPath')
        printf '/nix/store/uvicorn-out'
        ;;
      github:nixos/nixpkgs/*'#legacyPackages."aarch64-darwin"."python313Packages"."uvicorn":package: package.drvPath')
        printf '/nix/store/uvicorn.drv'
        ;;
      *)
        exit 1
        ;;
    esac
    ;;
  derivation)
    [ "$2" = show ] || exit 2
    case "$3" in
      /nix/store/pi.drv)
        printf '%s\n' '{"/nix/store/pi.drv":{"outputs":{"out":{"path":"/nix/store/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb-pi"}}}}'
        ;;
      /nix/store/bash.drv)
        printf '%s\n' '{"/nix/store/bash.drv":{"outputs":{"dev":{"path":"/nix/store/cccccccccccccccccccccccccccccccc-bash-dev"},"out":{"path":"/nix/store/dddddddddddddddddddddddddddddddd-bash"}}}}'
        ;;
      /nix/store/python314.drv)
        printf '%s\n' '{"/nix/store/python314.drv":{"outputs":{"out":{"path":"/nix/store/eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee-python3.14"}}}}'
        ;;
      /nix/store/uvicorn.drv)
        printf '%s\n' '{"/nix/store/uvicorn.drv":{"outputs":{"out":{"path":"/nix/store/ffffffffffffffffffffffffffffffff-uvicorn"}}}}'
        ;;
      *)
        exit 1
        ;;
    esac
    ;;
  config)
    [ "$2" = show ] && [ "$3" = --json ] || exit 2
    printf '%s\n' '{"substituters":{"value":["https://cache.nixos.org/","https://cache.numtide.com","https://robertderose.cachix.org"]}}'
    ;;
  path-info)
    [ "$2" = --store ] || exit 2
    store="$3"
    path="$4"
    case "$store:$path" in
      https://cache.numtide.com:/nix/store/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb-pi | \
        https://cache.nixos.org:/nix/store/cccccccccccccccccccccccccccccccc-bash-dev | \
        https://cache.numtide.com:/nix/store/cccccccccccccccccccccccccccccccc-bash-dev | \
        https://cache.nixos.org:/nix/store/dddddddddddddddddddddddddddddddd-bash | \
        https://nix-community.cachix.org:/nix/store/dddddddddddddddddddddddddddddddd-bash | \
        https://cache.numtide.com:/nix/store/dddddddddddddddddddddddddddddddd-bash | \
        https://cache.nixos.org:/nix/store/eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee-python3.14 | \
        https://cache.nixos.org:/nix/store/ffffffffffffffffffffffffffffffff-uvicorn)
        exit 0
        ;;
      *)
        exit 1
        ;;
    esac
    ;;
  *)
    printf 'unexpected nix call: %s\n' "$*" >&2
    exit 2
    ;;
esac
MOCK
chmod +x "$tmp/bin/nix"

run_check() {
  local package="$1"
  PATH="$tmp/bin:$PATH" usage_target="$package" "$ROOT/.mise/tasks/cache/package"
}

output="$(run_check pi)"
assert_contains "$output" "$ROOT#pi" 'llm-agents package resolution'
assert_contains "$output" 'Summary: 1/1 output(s) available' 'pi cache summary'

output="$(run_check '.#pi')"
assert_contains "$output" 'Resolved: .#pi' 'explicit local flake installable'

output="$(run_check 'github:numtide/llm-agents.nix#pi')"
assert_contains "$output" 'Resolved: github:numtide/llm-agents.nix#pi' 'explicit remote flake installable'

output="$(run_check bash)"
assert_contains "$output" 'bash-dev' 'multi-output package display'
assert_contains "$output" 'bash' 'main package output display'
assert_contains "$output" 'Summary: 2/2 output(s) available' 'multi-output summary'
assert_eq 0 "$(grep -c 'MISS\|robertderose.cachix.org' <<< "$output" || true)" 'cache misses should be omitted when hits exist'

output="$(run_check python3.14)"
assert_contains "$output" '#legacyPackages."aarch64-darwin"."python3.14"' 'literal dotted attribute resolution'
assert_contains "$output" 'https://cache.nixos.org' 'nixpkgs cache hit'

output="$(run_check python313Packages.uvicorn)"
assert_contains "$output" '#legacyPackages."aarch64-darwin"."python313Packages"."uvicorn"' 'nested attribute resolution'

if output="$(run_check '#legacyPackages.pi' 2>&1)"; then
  fail 'incomplete legacyPackages reference unexpectedly resolved'
fi
assert_contains "$output" "use a package name such as 'pi'" 'incomplete reference guidance'
