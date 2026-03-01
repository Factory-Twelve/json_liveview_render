# FAC-70 Implementation Plan

## Problem
The v0.3 release gate requires durable, auditable release artifacts for migration context and approval traceability. FAC-70 needs three explicit deliverables: (1) a migration summary from v0.2 local notes, (2) changelog caveats that clarify v0.3 migration/non-breaking context, and (3) an unambiguous team approval statement with date for local-use stability.

## Design
1. Create a dedicated migration summary markdown doc that captures:
   - v0.2 baseline contract surface.
   - v0.3 gate changes by area.
   - migration guidance for users moving from v0.2 to v0.3 candidate behavior.
   - caveats and deferred/experimental boundaries.
2. Create an explicit approval artifact markdown doc with:
   - approval statement language.
   - approver/team identity and date.
   - scope of the approval (local-use stability for v0.3 gate).
3. Link both artifacts from `RELEASE_READINESS.md` under a dedicated FAC-70 evidence section so reviewers can verify in one location.
4. Update `CHANGELOG.md` v0.3 release-draft notes with a migration context/caveats subsection that:
   - states non-breaking expectation for v0.2 core consumers.
   - points to the migration summary + approval artifact.
5. Update `.agent/notes/FAC-70.md` with implementation summary, validation results, and any follow-up constraints.

No Elixir runtime behavior changes are expected for this ticket.

## Files to Change
- `.agent/plans/FAC-70.md` (create/fill)
- `RELEASE_READINESS.md` (add FAC-70 evidence links)
- `CHANGELOG.md` (add v0.3 caveats + migration context)
- `docs/v0.3_migration_notes.md` (new migration summary artifact)
- `docs/v0.3_local_use_approval.md` (new explicit approval artifact)
- `.agent/notes/FAC-70.md` (create/fill)

## Key Decisions
- Store FAC-70 evidence as versioned markdown files under `docs/` to keep gate artifacts repo-local and reviewable in git history.
- Keep migration guidance explicit that v0.2 core APIs remain non-breaking in v0.3 scope lock, while v0.3 candidate/experimental surfaces require opt-in.
- Treat approval artifact as a local-release gate statement (not a global semver guarantee) and record an explicit calendar date.
- Satisfy “linked in parent” by adding clear evidence links in release-gate documentation and recording this in handoff notes for parent-gate auditing.

## Scope Boundaries
### In scope
- Authoring migration summary from current local v0.2/v0.3 notes.
- Updating changelog with caveats + migration context for v0.3.
- Creating explicit dated approval artifact for local-use stability.
- Linking artifacts in release-gate documentation.
- Running requested formatting/compile/test commands and documenting outcomes.

### Out of scope
- Changing library runtime code or public API behavior.
- Expanding scope beyond FAC-70 gate artifacts.
- Performing release publish/tag actions.
- Editing unrelated issue artifacts.

## Validation
- Verify migration summary document exists in `docs/` and is linked from `RELEASE_READINESS.md`.
- Verify changelog v0.3 release draft includes migration context and non-breaking caveats.
- Verify explicit approval artifact exists with clear statement + date and is linked from release-readiness docs.
- `mix format --check-formatted`
- `mix compile --warnings-as-errors`
- `MIX_PUBSUB=0 mix test`
