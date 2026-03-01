# FAC-66 Implementation Plan

## Problem
The v0.3 closeout gate must reflect real, current dependencies in Linear. FAC-66 currently needs a dependency audit to confirm required prereq issues exist and then sync `blockedBy` links so the gate is not driven by stale or missing references.

## Design
Perform a Linear metadata-only update flow:

1. Fetch FAC-66 relation state and all required prereq issues (`FAC-52, FAC-53, FAC-54, FAC-55, FAC-56, FAC-57, FAC-58, FAC-59, FAC-60, FAC-62`).
2. Audit for existence, identifier stability, and current state/title drift.
3. Build the effective dependency set from the required prereq list.
4. Update FAC-66 `blockedBy` links to exactly match the effective dependency set.
5. Remove stale dependency references by replacing the full `blockedBy` list in one update.
6. Record an audit summary and resulting dependency set in handoff notes.

No library/runtime code changes are expected for this ticket.

## Files to Change
- `.agent/plans/FAC-66.md` (create/update)
- `.agent/notes/FAC-66.md` (create/update)

## Key Decisions
- Treat the required prereq list in the ticket scope as the source of truth for FAC-66 dependencies unless an issue is missing/renamed in Linear.
- Use a full `blockedBy` replacement update to avoid partial-link drift and ensure stale references are removed.
- Keep work scoped to Linear issue metadata and local handoff docs only; no Elixir code changes.

## Scope Boundaries
### In scope
- Dependency audit for required prereqs (existence + current issue metadata).
- Sync FAC-66 `blockedBy` links to the audited effective dependency set.
- Document audit outcomes and final links in `.agent/notes/FAC-66.md`.

### Out of scope
- Changing dependencies for other gate issues (FAC-67, FAC-68, FAC-69, FAC-70).
- Modifying project source code, tests, or runtime behavior.
- Any release process edits beyond this issue’s dependency graph state.

## Validation
- Confirm FAC-66 `blockedBy` exactly matches the effective prereq set after update.
- Confirm no duplicate links remain.
- `MIX_PUBSUB=0 mix test`
- `mix format --check-formatted`
- `mix compile --warnings-as-errors`
