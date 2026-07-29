# Design — MAISON-005: Verified bootstrap artifacts

## Metadata

- Beads feature root: `maison-mol-pa6`
- Feature slug: `maison-005-verified-bootstrap-artifacts`
- Design path: `docs/src/features/maison-005-verified-bootstrap-artifacts/design.md`
- Implemented record: `docs/src/features/maison-005-verified-bootstrap-artifacts/index.md`
- Base branch: `chore-migrate-dstack-workflow`
- Status: draft
- Review priority: `P0`

## Feature Summary

Eliminate unverified remote code execution during bootstrap by using pinned release artifacts with checksum or signature verification and immutable plugin revisions.

## User Intent

The review identified `curl ... | sh` bootstrap paths for mise and Lix and mutable plugin repositories as unverified remote code execution.

## Goals

- No bootstrap path executes a downloaded script before verification.
- mise and Lix installers are pinned to reviewed versions and checksums or signatures.
- Mutable plugin repositories are pinned to immutable revisions.
- Docs provide a safe fresh-install path.

## Non-Goals

- Strict offline installation for every package manager.
- Replacing Nix binary cache trust policy.

## User-Facing Behavior

Operators keep using `maison` and mise tasks as the command surface. The feature changes the underlying safety,
validation, or documentation contract named above without requiring operators to learn an unrelated tool. When behavior
is unsafe or unsupported, Maison fails with an actionable message instead of silently continuing.

## Requirements

### Functional Requirements

- Bootstrap downloads artifacts to disk, verifies checksums or signatures, then executes verified local files only.
- Pinned version and verification data are checked into Maison or provided by the private overlay where site-specific.
- Tests fail on pipe-to-shell bootstrap patterns and mutable plugin refs.
- Operator docs include verification failure recovery.

### Quality Requirements

- Preserve Maison's Nix/Lix system ownership and mise user ownership boundary.
- Prefer tested Python stdlib implementations for stateful behavior. Python task files under `.mise/tasks/` are
  acceptable, including `usage` comments for argument validation and mise templating or sandboxing where useful.
- Do not introduce a Rust helper unless a later design proves Python cannot safely satisfy the filesystem or privilege
  boundary.
- Keep implementation small, reviewable, and covered by behavioral or fault-injection tests before relying on it.

### Compatibility and Migration Requirements

- Preserve supported platforms: `aarch64-darwin`, `aarch64-linux`, and `x86_64-linux`.
- Preserve the absence of Home Manager.
- Update existing commands in place rather than introducing parallel legacy paths.
- Public Maison remains generic and public-safe; personal/site configuration belongs in a private overlay where relevant.

## Existing Context

Maison currently documents a two-layer architecture where Nix/Lix owns privileged system state and mise owns user state.
The review of commit `ded7bbb745f34f1059930fc48eadafe267399ab2` identified this feature as required work. Existing
reader documentation under `docs/` describes the target operations and must be reconciled with delivered behavior.

## Proposed Design

Refactor bootstrap into explicit fetch, verify, and execute stages. The bootstrap task contains pinned metadata for supported platforms and verifies each mise and Lix artifact before execution. Plugin inputs use immutable commit or tag revisions with verification data where supported. The public command examples stop recommending unverified pipe-to-shell execution.

## Architecture Consistency

### Existing Patterns Reused

- Nix/Lix remains the privileged system layer.
- mise remains the user command and package/dotfile layer.
- `maison check` remains the repository-wide validation entrypoint.
- Python is the preferred home for stateful behavior that needs tests, parsing, locks, manifests, or recovery.

### Invariants Preserved

- A file, package, service, or preference has exactly one owner.
- Intel macOS remains unsupported.
- Remote deployment remains split between deploy-rs system-profile handling and Maison repository/user handling.
- Public Maison does not contain private infrastructure identity or trusted access material.

### New Decisions Introduced

- This feature adopts the concrete behavior described in **Proposed Design** as the supported Maison contract.

### Architecture Documentation Changes

Update the architecture and operations pages named in **Documentation Impact** so current reader-facing docs match the
implemented behavior.

## Operational Considerations

Operators should receive explicit errors, recovery instructions, and validation evidence for this feature's failure
modes. Recovery docs must distinguish Nix generation behavior, repository/source behavior, user convergence behavior,
and external package-manager side effects when those concerns apply.

## Documentation Impact

| Exact page | Create or update | Planned change | Owning Beads task |
|------------|------------------|----------------|-------------------|
| README.md | Update | Align reader-facing contract with MAISON-005: Verified bootstrap artifacts | Implementation tasks |
| docs/operations.md | Update | Align reader-facing contract with MAISON-005: Verified bootstrap artifacts | Implementation tasks |
| docs/recovery.md | Update | Align reader-facing contract with MAISON-005: Verified bootstrap artifacts | Implementation tasks |
| docs/task-reference.md | Update | Align reader-facing contract with MAISON-005: Verified bootstrap artifacts | Implementation tasks |
| `docs/src/features/maison-005-verified-bootstrap-artifacts/index.md` | Create during close-out | Preserve delivery and audit history | Close-out documentation |
| `docs/src/planned-features.md` | Update | Track roadmap status and Beads root | Planning |
| `docs/src/SUMMARY.md` | Update | Register this design and delivered record links | Planning / close-out |

## Validation Strategy

- Source-text guard tests banning `curl ... | sh` and mutable plugin refs in bootstrap paths.
- Behavioral tests for checksum/signature success and failure.
- `mise -E dev run check` and `uv run scripts/check-docs.py`.

## Implementation Decomposition

- `maison-005-verified-bootstrap-artifacts bootstrap-contract` — Add verified-bootstrap and immutable-plugin tests.
- `maison-005-verified-bootstrap-artifacts bootstrap-implementation` — Implement verified artifact bootstrap.

## Dependencies and Parallelism

This feature follows the Maison review order. Its implementation tasks depend on specification reconciliation. Sibling
implementation tasks may run in parallel only when they do not edit the same command path, test file, or documentation
page.

## Rollout and Migration

Roll out by updating tests and docs first, then replacing the existing implementation path. Existing commands keep their
names unless a feature explicitly narrows unsafe behavior.

## Risks and Tradeoffs

- Safety fixes may temporarily reduce permissive behavior that previously appeared to work.
- Deployment and recovery changes require fault-injection coverage because ordinary happy-path tests are insufficient.
- Keeping shell and mise task compatibility while moving logic into Python may require small adapter changes.

## Rejected Alternatives

- Broad rewrite before fixing the review findings.
- Preserving unsafe legacy paths as supported behavior.
- Storing private infrastructure identity in public Maison defaults.

## Open Questions

None.

## Deferred Decisions

None.

## Planning Record

### Questions Asked and Answers

- Stateful Maison behavior should move into tested Python implementations. `.mise/tasks/` may contain Python task files
  and may use `usage` comments, task templating, and sandboxing.
- The default privileged deployment account is `maison-deploy`.
- Maison is the reusable vehicle; a tracked private overlay repository is the driver for personal/site configuration.
- Fresh setup supports `--overlay <git-url-or-path>`, prompts only when interactive, and fails clearly when a required
  overlay is missing in non-interactive mode.
- Public examples should be real workable starter configurations without personal infrastructure identity.

### Assumptions

- The reviewed commit and review summary are authoritative planning evidence for this remediation roadmap.
- Feature branches should base on `chore-migrate-dstack-workflow` until the migration branch is delivered.

### Design Changes During Planning

- The private inventory model changed from untracked local TOML to a tracked private overlay repository to preserve
  Maison's durability and replication goals.

### Source Material

- Maison review summary for commit `ded7bbb745f34f1059930fc48eadafe267399ab2`.
- Current Maison documentation under `README.md` and `docs/`.
