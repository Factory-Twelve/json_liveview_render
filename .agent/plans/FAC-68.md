# FAC-68 Implementation Plan

## Problem
The v0.3 closeout gate needs a concrete, reusable release-readiness page with explicit smoke-test coverage and operator actions. Today, the parent gate references the need for this checklist, but the repository does not yet contain a single canonical checklist + smoke matrix with command-level execution, pass/fail signals, and failure response steps.

## Design
1. Add a dedicated one-page release-readiness checklist markdown doc in the repo root so it is source-controlled and easy to link from Linear.
2. Include in that page:
   - owner and checklist path,
   - a smoke matrix covering catalog, registry, permissions, bindings, and partial streaming,
   - exact command-level execution steps for each smoke area,
   - expected pass/fail signals,
   - rollback/retest actions for failure states.
3. Wire the new checklist into project docs metadata so it is included in generated ExDoc output.
4. Update the parent gate ticket (`FAC-61`) with a direct link to the checklist file path in the repo.
5. Record decisions and follow-up context in `.agent/notes/FAC-68.md`.

## Files to Change
- `.agent/plans/FAC-68.md` (create/update)
- `.agent/notes/FAC-68.md` (create/update)
- `RELEASE_READINESS.md` (create)
- `README.md` (add docs link to checklist)
- `mix.exs` (include checklist in package/docs extras)

## Key Decisions
- Use a dedicated top-level markdown file (`RELEASE_READINESS.md`) as the canonical checklist source so it can be referenced by path from both repo docs and Linear.
- Keep the smoke matrix command-first and deterministic, using existing project commands (`mix test`, `mix format --check-formatted`, `mix compile --warnings-as-errors`) plus focused test filters where applicable.
- Treat Linear acceptance of parent-linking as satisfied by posting a durable FAC-61 comment containing the repository path link.

## Scope Boundaries
### In scope
- Authoring a one-page release-readiness checklist and smoke matrix.
- Adding explicit pass/fail signals and rollback/retest actions.
- Updating docs metadata and README links so the checklist is discoverable.
- Adding a checklist-path link on the FAC-61 parent ticket.
- Updating FAC-68 handoff notes.

### Out of scope
- Implementing new runtime behavior for catalog/registry/permissions/bindings/streaming.
- Changing release criteria beyond documenting and operationalizing existing gate checks.
- Modifying unrelated issues or gate dependencies.

## Validation
- `mix format --check-formatted`
- `mix compile --warnings-as-errors`
- `MIX_PUBSUB=0 mix test`
- Manual doc validation:
  - Checklist page contains owner + command paths.
  - Smoke matrix includes required five areas with expected pass/fail signals.
  - Failure states include rollback + retest actions.
  - FAC-61 has a checklist-path link comment.
