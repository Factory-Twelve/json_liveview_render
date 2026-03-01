# FAC-69 Implementation Plan

## Problem
The v0.3 gate requires a current, explicit regression sweep for high-priority work. FAC-69 must confirm the live P1/P2 regression status in Linear for the `json_liveview_render` project, ensure each open high-priority regression has clear ownership and mitigation trigger, and document escalation so the parent gate cannot be closed while unresolved blockers remain.

## Design
1. Query current Linear issue data for `json_liveview_render` scoped to high-priority regressions (P1/P2) and capture state, assignee, and blocker context.
2. Produce a regression sweep note with current counts by priority and explicit per-issue status for any open high-priority items.
3. If any P1/P2 items remain open, post an escalation note that includes concrete completion trigger(s) and an explicit gate rule that parent closure is blocked until those items are resolved.
4. Attach the sweep/escalation note(s) to FAC-69 and mirror the closure guard on the parent gate issue for enforcement visibility.
5. Record results and follow-up details in `.agent/notes/FAC-69.md`.

No library/runtime code changes are expected for this ticket.

## Files to Change
- `.agent/plans/FAC-69.md` (create/update)
- `.agent/notes/FAC-69.md` (create/update)

## Key Decisions
- Treat Linear project issues in `json_liveview_render` with priority `1` or `2` as the source set for high-priority sweep counts.
- Treat non-completed state as open blocker status for gate purposes.
- Satisfy acceptance criteria through durable Linear comments that include counts, blocker links, owner/mitigation details, and explicit parent closeout guard language.
- Keep implementation scoped to issue metadata updates and local handoff documentation.

## Scope Boundaries
### In scope
- Querying live Linear high-priority issue state for v0.3 regression sweep.
- Posting FAC-69 sweep note with counts by priority.
- Posting explicit escalation/closure guard when any P1/P2 remain open.
- Updating FAC-69 handoff notes.

### Out of scope
- Changing application/library source code.
- Reprioritizing issues or rewriting unrelated ticket content.
- Updating dependency structure beyond FAC-69-required sweep/escalation notes.

## Validation
- Verify FAC-69 has a regression sweep note with current priority counts.
- Verify all open P1/P2 entries in the note include owner + concrete completion trigger.
- Verify parent gate issue has explicit closeout guard language when unresolved blockers exist.
- `mix format --check-formatted`
- `mix compile --warnings-as-errors`
- `MIX_PUBSUB=0 mix test`
