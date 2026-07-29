# Legacy workflow baseline

Generated: `2026-07-29T17:14:12+00:00`

## Documentation

- Status: `passed`
- Command: `mise -E dev run docs:build`
- Note: Explicit baseline documentation command.

## Tests

- Status: `passed`
- Command: `mise -E dev run check`
- Note: Explicit baseline test command.

## Hk

- Status: `evaluable`
- Command: `pkl eval hk.pkl`
- Note: Pkl evaluation passed.

## Resolution

- Write eligible: `true`
- Unresolved: none
- Resolution flags: documentation=supplied; tests=supplied
- Uncovered candidates: none
- Residual limitations: .: Python test files exist but pyproject.toml is missing

## Validation partitions

- None recorded; legacy documentation/tests fields remain authoritative.

## Capability inventory

- Layout: `single-package`
- Config roots: `.`
- Documentation evidence: `README.md`, `docs/add-a-host.md`, `docs/add-a-tool.md`, `docs/add-an-app.md`, `docs/architecture.md`, `docs/book.toml`, `docs/deployment.md`, `docs/migration-contract.md`, `docs/operations.md`, `docs/package-policy.md`, `docs/recovery.md`, `docs/refactor-report.md`, `docs/src/SUMMARY.md`, `docs/src/add-a-host.md`, `docs/src/add-a-tool.md`, `docs/src/add-an-app.md`, `docs/src/architecture.md`, `docs/src/deployment.md`, `docs/src/introduction.md`, `docs/src/migration-contract.md`, `docs/src/operations.md`, `docs/src/package-policy.md`, `docs/src/recovery.md`, `docs/src/refactor-report.md`, `docs/src/task-reference.md`, `docs/task-reference.md`, `dotfiles/opencode/README.md`, `dotfiles/pi/AGENTS.md`
- Test evidence: `tests/test_config_edit.py`, `tests/test_topology.py`
- CI workflows: `.github/workflows/cache-refresh.yml`, `.github/workflows/ci.yml`, `.github/workflows/docs.yml`, `.github/workflows/hk.yml`
- Ambiguities: .: Python test files exist but pyproject.toml is missing

### Packages

- `.`
  - Manifests:
  - Test evidence: `tests/test_config_edit.py`, `tests/test_topology.py`

### Proposed commands

- `root-book-build` (documentation): argv=`mdbook build docs`; cwd=`.`; provenance=`docs/book.toml`

### CI command evidence

- `.github/workflows/cache-refresh.yml:42`: `nix flake update` (ci-evidence-only)
- `.github/workflows/cache-refresh.yml:46`: `if git diff --quiet -- flake.lock; then
echo "changed=false" >> "$GITHUB_OUTPUT"
exit 0
fi
echo "changed=true" >> "$GITHUB_OUTPUT"
git diff --stat -- flake.lock >> "$GITHUB_STEP_SUMMARY"` (ci-evidence-only)
- `.github/workflows/cache-refresh.yml:101`: `kernel="$(uname -s | tr '[:upper:]' '[:lower:]')"
arch="$(uname -m)"
case "$arch" in
arm64|aarch64) arch="aarch64" ;;
x86_64) arch="x86_64" ;;
*)
echo "Unsupported architecture: $arch" >&2
exit 1
;;
esac
target="$arch-$kernel"
echo "Refreshing cache targets for $target"
bash .github/scripts/build-platform-targets.sh "$target"` (ci-evidence-only)
- `.github/workflows/cache-refresh.yml:158`: `if git diff --quiet -- flake.lock; then
echo "flake.lock already matches refreshed artifact"
echo "pr_number=" >> "$GITHUB_OUTPUT"
exit 0
fi
branch="automation/refresh-flake-lock"
remote_branch_sha="$(git ls-remote --heads origin "$branch" | awk '{print $1}')"
git config user.name "robborg-the-creator[bot]"
git config user.email "280037799+robborg-the-creator[bot]@users.noreply.github.com"
git checkout -b "$branch"
git add flake.lock
git commit -m "chore: refresh flake lock"
if [ -n "$remote_branch_sha" ]; then
git push --force-with-lease="refs/heads/$branch:$remote_branch_sha" origin "$branch"
else
git push --set-upstream origin "$branch"
fi
pr_number="$(gh pr list \
--state open \
--head "$branch" \
--json number \
--jq '.[0].number')"
if [ -n "$pr_number" ] && [ "$pr_number" != "null" ]; then
gh pr edit "$pr_number" \
--title "chore: refresh flake lock" \
--body "Automated flake.lock refresh after successful cache warmup."
else
gh pr create \
--base main \
--head "$branch" \
--title "chore: refresh flake lock" \
--body "Automated flake.lock refresh after successful cache warmup."
pr_number="$(gh pr list \
--state open \
--head "$branch" \
--json number \
--jq '.[0].number')"
fi
echo "pr_number=$pr_number" >> "$GITHUB_OUTPUT"` (ci-evidence-only)
- `.github/workflows/cache-refresh.yml:246`: `gh pr merge "$PR_NUMBER" --repo "$GH_REPO" --admin --squash` (ci-evidence-only)
- `.github/workflows/ci.yml:39`: `mise -E dev install` (ci-evidence-only)
- `.github/workflows/ci.yml:41`: `mise -E dev run check` (ci-evidence-only)
- `.github/workflows/ci.yml:64`: `kernel="$(uname -s | tr '[:upper:]' '[:lower:]')"
arch="$(uname -m)"
case "$arch" in
arm64 | aarch64) arch=aarch64 ;;
x86_64 | amd64) arch=x86_64 ;;
*) echo "Unsupported architecture: $arch" >&2; exit 1 ;;
esac
bash .github/scripts/build-platform-targets.sh "$arch-$kernel"` (ci-evidence-only)
- `.github/workflows/ci.yml:91`: `bash -n bootstrap.sh
./bootstrap.sh --help
cat bootstrap.sh | bash -s -- --help
PYTHONPATH=tests python3 -m unittest -v \
test_topology.MigrationBehaviorTest.test_bootstrap_help_pipe_and_clone_handoff` (ci-evidence-only)
- `.github/workflows/docs.yml:39`: `mise -E dev run docs:build` (ci-evidence-only)
- `.github/workflows/hk.yml:33`: `mise -E dev install
mise -E dev exec -- hk check -a` (ci-evidence-only)
