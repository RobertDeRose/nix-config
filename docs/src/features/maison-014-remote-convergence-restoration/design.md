# Design — MAISON-014: Remote convergence restoration

## Metadata

- Beads feature root: `maison-mol-vhhy`
- Feature slug: `maison-014-remote-convergence-restoration`
- Design path: `docs/src/features/maison-014-remote-convergence-restoration/design.md`
- Implemented record: `docs/src/features/maison-014-remote-convergence-restoration/index.md`
- Base branch: `dev`
- Status: draft
- Review priority: `P1`

## Feature Summary

Restore user state after failed remote convergence by rerunning restricted convergence from the restored prior repository.

## User Intent

A failed deployment restores repository source but can leave links and other user state pointing at the failed revision.

## Goals

- After remote user convergence failure, restore prior repository source and reconverge user state from that revision.
- Restrict recovery convergence to reversible user state.
- Report irreversible package-side effects separately.

## Non-Goals

- Guaranteeing package-manager rollback for completed external package operations.
- Rolling back the Nix system profile outside deploy-rs semantics.

## User-Facing Behavior

Operators keep using `maison` and mise tasks as the command surface. The feature changes the underlying safety,
validation, or documentation contract named above without requiring operators to learn an unrelated tool. When behavior
is unsafe or unsupported, Maison fails with an actionable message instead of silently continuing.

## Requirements

### Functional Requirements

- The failure path runs a restricted convergence operation from the restored prior repository after MAISON-002 recovery succeeds.
- Restricted convergence repairs dotfile links, generated JSON, and Maison-owned user state that can be safely reapplied.
- Irreversible package/app side effects are detected and reported as follow-up recovery work.
- Docs distinguish repository rollback, user reconvergence, and package side effects.

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

Add a post-rollback recovery phase to remote deployment. Once the prior repository is restored and revision-verified, Maison invokes a restricted user convergence mode from that restored source. The mode repairs links and generated user state without attempting unsafe package downgrades, then emits a structured side-effect report.

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
| docs/deployment.md | Update | Align reader-facing contract with MAISON-014: Remote convergence restoration | Implementation tasks |
| docs/recovery.md | Update | Align reader-facing contract with MAISON-014: Remote convergence restoration | Implementation tasks |
| docs/operations.md | Update | Align reader-facing contract with MAISON-014: Remote convergence restoration | Implementation tasks |
| docs/task-reference.md | Update | Align reader-facing contract with MAISON-014: Remote convergence restoration | Implementation tasks |
| `docs/src/features/maison-014-remote-convergence-restoration/index.md` | Create during close-out | Preserve delivery and audit history | Close-out documentation |
| `docs/src/planned-features.md` | Update | Track roadmap status and Beads root | Planning |
| `docs/src/SUMMARY.md` | Update | Register this design and delivered record links | Planning / close-out |

## Validation Strategy

- Fault-injection tests where failed convergence leaves links pointing at the failed revision.
- Tests proving restricted recovery runs from the restored old revision and reports package side effects.
- `mise -E dev run check` and `uv run scripts/check-docs.py`.

## Implementation Decomposition

- `maison-014-remote-convergence-restoration reconverge-contract` — Add failed remote convergence restoration tests.
- `maison-014-remote-convergence-restoration reconverge-implementation` — Implement post-rollback restricted user convergence.

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
- Feature branches should base on `dev`.

### Design Changes During Planning

- The private inventory model changed from untracked local TOML to a tracked private overlay repository to preserve
  Maison's durability and replication goals.

### Source Material

- Maison review summary for commit `ded7bbb745f34f1059930fc48eadafe267399ab2`.
- Current Maison documentation under `README.md` and `docs/`.
